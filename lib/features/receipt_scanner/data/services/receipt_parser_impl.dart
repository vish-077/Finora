import 'package:finora/features/receipt_scanner/domain/entities/receipt_data.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt_item.dart';
import 'package:finora/features/receipt_scanner/domain/services/receipt_parser.dart';

class ReceiptParserImpl implements ReceiptParser {
  const ReceiptParserImpl();

  @override
  ReceiptData parse(String ocrText) {
    if (ocrText.isEmpty) {
      return ReceiptData(
        merchantName: 'Unknown Merchant',
        totalAmount: 0.0,
        date: DateTime.now(),
        time: '',
        category: 'Others',
        paymentMethod: 'cash',
        tax: 0.0,
        discount: 0.0,
        items: const [],
        confidenceScore: 0.0,
      );
    }

    final lines = ocrText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // 1. Merchant Name Search
    String merchantName = 'Unknown Merchant';
    for (final line in lines) {
      final containsNumber = RegExp(r'\d').hasMatch(line);
      final isHeaderLabel = line.toLowerCase().contains('tax invoice') ||
          line.toLowerCase().contains('receipt') ||
          line.toLowerCase().contains('welcome') ||
          line.toLowerCase().contains('bill') ||
          line.toLowerCase().contains('date') ||
          line.toLowerCase().contains('tel:') ||
          line.toLowerCase().contains('phone:');
      
      if (!containsNumber && !isHeaderLabel && line.length > 2) {
        merchantName = line;
        break;
      }
    }

    // 2. Extract Date
    DateTime date = DateTime.now();
    final dateRegex = RegExp(
      r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})|(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})',
    );
    bool foundDate = false;
    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        try {
          if (match.group(1) != null) {
            final dayOrMonth1 = int.parse(match.group(1)!);
            final dayOrMonth2 = int.parse(match.group(2)!);
            int year = int.parse(match.group(3)!);
            if (year < 100) year += 2000;
            if (dayOrMonth1 > 12) {
              date = DateTime(year, dayOrMonth2, dayOrMonth1);
            } else {
              date = DateTime(year, dayOrMonth1, dayOrMonth2);
            }
          } else {
            final year = int.parse(match.group(4)!);
            final month = int.parse(match.group(5)!);
            final day = int.parse(match.group(6)!);
            date = DateTime(year, month, day);
          }
          foundDate = true;
          break;
        } catch (_) {}
      }
    }

    // 3. Extract Time
    String time = '';
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})(:\d{2})?\s*(AM|PM|am|pm)?');
    for (final line in lines) {
      final match = timeRegex.firstMatch(line);
      if (match != null) {
        time = match.group(0)!;
        break;
      }
    }

    // 4. Extract Prices & Amounts
    double totalAmount = 0.0;
    double tax = 0.0;
    double discount = 0.0;
    final List<ReceiptItem> items = [];
    final priceRegex = RegExp(r'[-+]?\s*\d+[\.,]\d{2}');

    for (final line in lines) {
      final matches = priceRegex.allMatches(line).toList();
      if (matches.isNotEmpty) {
        final lastMatch = matches.last;
        final priceStr = lastMatch.group(0)!.replaceAll(' ', '').replaceAll(',', '.');
        final price = double.tryParse(priceStr) ?? 0.0;

        final lineLower = line.toLowerCase();
        final itemName = line.substring(0, lastMatch.start).trim().replaceAll(RegExp(r'[*:#]'), '');
        
        if (lineLower.contains('total') || 
            lineLower.contains('net') || 
            lineLower.contains('amount due') || 
            lineLower.contains('subtotal') || 
            lineLower.contains('tax') || 
            lineLower.contains('vat') || 
            lineLower.contains('discount') || 
            lineLower.contains('cgst') || 
            lineLower.contains('sgst')) {
          if (lineLower.contains('grand total') || 
              (lineLower.contains('total') && !lineLower.contains('subtotal') && !lineLower.contains('tax'))) {
            if (price > totalAmount) totalAmount = price;
          } else if (lineLower.contains('tax') || 
                     lineLower.contains('vat') || 
                     lineLower.contains('gst') || 
                     lineLower.contains('cgst') || 
                     lineLower.contains('sgst')) {
            tax += price;
          } else if (lineLower.contains('discount') || 
                     lineLower.contains('disc') || 
                     lineLower.contains('less')) {
            discount += price.abs();
          }
        } else if (itemName.length > 2 && price > 0.0) {
          items.add(ReceiptItem(name: itemName, price: price));
        }
      }
    }

    if (totalAmount == 0.0) {
      for (final line in lines) {
        final lineLower = line.toLowerCase();
        if (lineLower.contains('total') || lineLower.contains('amount') || lineLower.contains('pay')) {
          final match = priceRegex.firstMatch(line);
          if (match != null) {
            final priceStr = match.group(0)!.replaceAll(' ', '').replaceAll(',', '.');
            final price = double.tryParse(priceStr) ?? 0.0;
            if (price > totalAmount) {
              totalAmount = price;
            }
          }
        }
      }
    }

    if (totalAmount == 0.0) {
      double maxPrice = 0.0;
      for (final line in lines) {
        final match = priceRegex.firstMatch(line);
        if (match != null) {
          final priceStr = match.group(0)!.replaceAll(' ', '').replaceAll(',', '.');
          final price = double.tryParse(priceStr) ?? 0.0;
          if (price > maxPrice) {
            maxPrice = price;
          }
        }
      }
      totalAmount = maxPrice;
    }

    // 5. Payment Method Detection
    String paymentMethod = 'cash';
    final textLower = ocrText.toLowerCase();
    if (textLower.contains('upi') || 
        textLower.contains('gpay') || 
        textLower.contains('paytm') || 
        textLower.contains('phonepe') || 
        textLower.contains('google pay')) {
      paymentMethod = 'upi';
    } else if (textLower.contains('credit card') || 
               textLower.contains('visa') || 
               textLower.contains('mastercard') || 
               textLower.contains('amex')) {
      paymentMethod = 'creditCard';
    } else if (textLower.contains('debit card') || textLower.contains('debit')) {
      paymentMethod = 'debitCard';
    } else if (textLower.contains('wallet') || 
               textLower.contains('apple pay') || 
               textLower.contains('samsung pay')) {
      paymentMethod = 'wallet';
    } else if (textLower.contains('bank transfer') || 
               textLower.contains('neft') || 
               textLower.contains('rtgs') || 
               textLower.contains('netbanking')) {
      paymentMethod = 'bankTransfer';
    }

    // 6. Heuristic Confidence Score
    double confidence = 0.0;
    if (merchantName != 'Unknown Merchant') confidence += 0.25;
    if (totalAmount > 0.0) confidence += 0.35;
    if (foundDate) confidence += 0.20;
    if (time.isNotEmpty) confidence += 0.10;
    if (items.isNotEmpty) confidence += 0.10;

    return ReceiptData(
      merchantName: merchantName,
      totalAmount: totalAmount,
      date: date,
      time: time,
      category: 'Others',
      paymentMethod: paymentMethod,
      tax: tax,
      discount: discount,
      items: items,
      confidenceScore: confidence,
    );
  }
}
