import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';

import 'package:finora/features/ai/data/repositories/local_insight_repository.dart';
import 'package:finora/features/ai/domain/entities/ai_entities.dart';

const _userId = 'u1';

void main() {
  late Directory tempDir;
  late SqlBox txBox;
  late SqlBox budgetBox;
  late LocalInsightRepositoryImpl repo;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('finora_health_test');
    AppDatabase.initInMemory();
  });

  setUp(() async {
    txBox = await AppDatabase.openBox('health_tx');
    budgetBox = await AppDatabase.openBox('health_budget');
    await txBox.clear();
    await budgetBox.clear();
    repo = LocalInsightRepositoryImpl(
      transactionBox: txBox,
      budgetBox: budgetBox,
    );
  });

  tearDownAll(() async {
    await AppDatabase.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Rows are cached as JSON strings, matching the feature local sources.
  Future<void> addTx({
    required String id,
    required double amount,
    required String type,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    await txBox.put(
      id,
      jsonEncode({
        'id': id,
        'user_id': _userId,
        'title': 'row $id',
        'amount': amount,
        'transaction_type': type,
        'payment_method': 'cash',
        'category_id': categoryId,
        'transaction_date': DateTime(now.year, now.month, now.day)
            .toIso8601String(),
      }),
    );
  }

  Future<void> addBudget({
    required String id,
    required double amount,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    await budgetBox.put(
      id,
      jsonEncode({
        'id': id,
        'user_id': _userId,
        'category_id': categoryId,
        'amount': amount,
        'month': now.month,
        'year': now.year,
      }),
    );
  }

  Future<FinancialHealth> health() async {
    final result = await repo.getFinancialHealth(_userId);
    return result.getRight().toNullable()!;
  }

  group('health score', () {
    // Regression: budgetAdherence defaulted to a perfect 1.0 when no budget
    // existed, and the score was two 50-point terms — so it could only ever
    // land on 50 or 100 for the many users with no budgets set.
    test('does not fabricate perfect budget adherence with no budgets',
        () async {
      await addTx(id: 't1', amount: 1000, type: 'income');
      await addTx(id: 't2', amount: 500, type: 'expense');

      final h = await health();

      expect(h.budgetAdherence, isNull,
          reason: 'no budget means not measurable, not 100%');
      // The missing factor must not be scored at all, so it cannot contribute
      // the flat 50 points that pinned the old ring.
      expect(h.factors.any((f) => f.label == 'Budget adherence'), isFalse);
    });

    // With the old two-term maths a mediocre month still collapsed onto 50 or
    // 100. It should now land somewhere sensible in between.
    test('a mediocre month scores between the extremes', () async {
      await addTx(id: 'i', amount: 1000, type: 'income');
      await addTx(id: 'e', amount: 900, type: 'expense');

      final score = (await health()).score;

      expect(score, greaterThan(20));
      expect(score, lessThan(80));
      expect(score, isNot(50));
      expect(score, isNot(100));
    });

    test('produces varied scores across varied inputs, not just 50/100',
        () async {
      final scores = <int>{};

      for (final spend in [0.0, 200.0, 400.0, 600.0, 800.0, 950.0]) {
        await txBox.clear();
        await addTx(id: 'inc', amount: 1000, type: 'income');
        if (spend > 0) {
          await addTx(id: 'exp', amount: spend, type: 'expense');
        }
        scores.add((await health()).score);
      }

      // The old maths collapsed all of these onto 2 values.
      expect(scores.length, greaterThanOrEqualTo(4),
          reason: 'score must vary continuously with spending, got $scores');
    });

    test('reports no data when nothing is recorded', () async {
      final h = await health();

      expect(h.hasNoData, isTrue);
      expect(h.factors, isEmpty);
      expect(h.savingsRatio, isNull);
      expect(h.budgetAdherence, isNull);
      expect(h.score, 0);
    });

    test('savingsRatio is null without income, not zero', () async {
      await addTx(id: 'e1', amount: 300, type: 'expense');

      expect((await health()).savingsRatio, isNull);
    });

    test('strong saver scores well above a heavy spender', () async {
      await addTx(id: 'i', amount: 1000, type: 'income');
      await addTx(id: 'e', amount: 100, type: 'expense');
      final good = (await health()).score;

      await txBox.clear();
      await addTx(id: 'i2', amount: 1000, type: 'income');
      await addTx(id: 'e2', amount: 990, type: 'expense');
      final bad = (await health()).score;

      expect(good, greaterThan(bad));
      expect(good, greaterThan(70));
      expect(bad, lessThan(40));
    });

    test('only budgeted-category spend counts against the budget', () async {
      await addTx(id: 'i', amount: 1000, type: 'income');
      await addTx(id: 'inBudget', amount: 100, type: 'expense', categoryId: 'c1');
      await addTx(id: 'outside', amount: 400, type: 'expense', categoryId: 'c9');
      await addBudget(id: 'b1', amount: 500, categoryId: 'c1');

      final h = await health();

      // 100 of the 500 budget used → 80% remaining. Charging the unbudgeted
      // 400 as well would have wrongly reported 0%.
      expect(h.budgetAdherence, closeTo(0.8, 0.001));
    });

    test('over-budget adherence floors at zero rather than going negative',
        () async {
      await addTx(id: 'i', amount: 1000, type: 'income');
      await addTx(id: 'e', amount: 900, type: 'expense', categoryId: 'c1');
      await addBudget(id: 'b1', amount: 100, categoryId: 'c1');

      expect((await health()).budgetAdherence, 0.0);
    });

    test('score stays within 0-100 and coverage grows with more data',
        () async {
      await addTx(id: 'i', amount: 1000, type: 'income');
      await addTx(id: 'e', amount: 200, type: 'expense', categoryId: 'c1');
      final withoutBudget = await health();

      await addBudget(id: 'b1', amount: 500, categoryId: 'c1');
      final withBudget = await health();

      expect(withoutBudget.score, inInclusiveRange(0, 100));
      expect(withBudget.score, inInclusiveRange(0, 100));
      expect(withBudget.dataCoverage,
          greaterThan(withoutBudget.dataCoverage));
      expect(withBudget.dataCoverage, closeTo(1.0, 0.001));
    });
  });
}
