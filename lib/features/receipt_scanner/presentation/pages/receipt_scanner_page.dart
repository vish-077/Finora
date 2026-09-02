import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/shared/enums/transaction_type.dart';
import 'package:finora/shared/widgets/finora_button.dart';
import 'package:finora/core/constants/route_constants.dart';

import 'package:finora/features/receipt_scanner/domain/entities/receipt.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt_data.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt_item.dart';
import 'package:finora/features/receipt_scanner/presentation/viewmodels/ocr_controller.dart';
import 'package:finora/features/receipt_scanner/presentation/viewmodels/receipt_scanner_controller.dart';
import 'package:finora/features/receipt_scanner/presentation/widgets/expense_confirm_dialog.dart';
import 'package:finora/features/settings/presentation/viewmodels/settings_controller.dart';

class ReceiptScannerPage extends ConsumerStatefulWidget {
  const ReceiptScannerPage({super.key});

  @override
  ConsumerState<ReceiptScannerPage> createState() => _ReceiptScannerPageState();
}

class _ReceiptScannerPageState extends ConsumerState<ReceiptScannerPage> with TickerProviderStateMixin {
  late TabController _tabController;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();

  // Animation controller for the scanning line
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeCamera();

    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tabController.dispose();
    _scanAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      // Add a small delay to let the camera native thread/shutter finish and settle
      await Future.delayed(const Duration(milliseconds: 300));
      await _processImageFile(image.path);
    } catch (e) {
      _showErrorSnackBar('Capture failed: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Add a small delay to allow the image picker activity to completely finish closing on Android
        await Future.delayed(const Duration(milliseconds: 300));
        await _processImageFile(image.path);
      }
    } catch (e) {
      _showErrorSnackBar('Gallery pick failed: $e');
    }
  }

  Future<void> _processImageFile(String path) async {
    // 1. Crop image before processing
    final croppedPath = await _cropImage(path);
    if (croppedPath == null) return; // User cancelled crop

    // Add a short delay to let the cropper activity transition finish and settle before displaying dialog
    await Future.delayed(const Duration(milliseconds: 300));

    // 2. Start OCR and parsing
    ref.read(ocrControllerProvider.notifier).clear();
    
    // Open loading overlay
    _showLoadingDialog();
    
    try {
      await ref.read(ocrControllerProvider.notifier).processReceipt(croppedPath);
    } catch (e) {
      debugPrint('Error in processReceipt: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Always close loading dialog under all circumstances
      }
    }

    final ocrState = ref.read(ocrControllerProvider);
    if (ocrState.hasError) {
      _showErrorSnackBar('OCR Failed: ${ocrState.error}');
    } else if (ocrState.hasValue && ocrState.value != null) {
      if (ocrState.value!.merchantName.startsWith('Mock')) {
        _showWarningSnackBar('ML Kit model not ready. Loaded simulated receipt for testing.');
      }
      _showReviewBottomSheet(croppedPath, ocrState.value!);
    }
  }

  Future<String?> _cropImage(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop & Rotate',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop & Rotate',
        ),
      ],
    );
    return croppedFile?.path;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    AppSpacing.vLg,
                    const Text(
                      'Analyzing Receipt...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    AppSpacing.vSm,
                    Text(
                      'Running on-device AI text recognition...',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.amber[800],
      ),
    );
  }

  void _showReviewBottomSheet(String imagePath, ReceiptData initialData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReceiptReviewSheet(
        imagePath: imagePath,
        initialData: initialData,
        onDone: () {
          ref.read(receiptScannerControllerProvider.notifier).search('');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: 'Scan'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildScanTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    if (!_isCameraInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            AppSpacing.vLg,
            const Text('Starting Camera...', style: TextStyle(color: Colors.grey)),
            AppSpacing.vMd,
            FinoraButton(
              label: 'Choose from Gallery',
              onPressed: _pickFromGallery,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),

        // Scanning Overlay (Custom Animated scan line and border)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  // Outer darkened border
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.transparent,
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: MediaQuery.of(context).size.height * 0.5,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Glowing Crop Border
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.height * 0.5,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  // Animated Scanning Line
                  Positioned(
                    top: (MediaQuery.of(context).size.height * 0.25) +
                        (_scanAnimation.value * MediaQuery.of(context).size.height * 0.5),
                    left: MediaQuery.of(context).size.width * 0.1,
                    right: MediaQuery.of(context).size.width * 0.1,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Flash Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(16),
                ),
                icon: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFlash,
              ),

              // Capture Button
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // Gallery Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _pickFromGallery,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final state = ref.watch(receiptScannerControllerProvider);

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search merchant, item, category...',
            leading: const Icon(Icons.search),
            onChanged: (val) {
              ref.read(receiptScannerControllerProvider.notifier).search(val);
            },
          ),
        ),

        // History List
        Expanded(
          child: state.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                      AppSpacing.vLg,
                      Text(
                        _searchController.text.isEmpty ? 'No receipts scanned yet' : 'No matching receipts found',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final receipt = list[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(receipt.imagePath),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.receipt),
                        ),
                      ),
                      title: Text(
                        receipt.parsedData.merchantName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${DateFormat('yMMMd').format(receipt.parsedData.date)} • ${receipt.parsedData.category}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${receipt.parsedData.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        _showReceiptViewerDialog(receipt);
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, _) => Center(child: Text('Error loading history: $err')),
          ),
        ),
      ],
    );
  }

  void _showReceiptViewerDialog(Receipt receipt) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Receipt Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  AppSpacing.vMd,
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(receipt.imagePath),
                      height: 240,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                  AppSpacing.vLg,
                  // Data Details
                  ListTile(
                    title: const Text('Merchant Name'),
                    subtitle: Text(receipt.parsedData.merchantName),
                  ),
                  ListTile(
                    title: const Text('Total Amount'),
                    subtitle: Text('₹${receipt.parsedData.totalAmount.toStringAsFixed(2)}'),
                  ),
                  ListTile(
                    title: const Text('Date & Time'),
                    subtitle: Text('${DateFormat('yMMMd').format(receipt.parsedData.date)} ${receipt.parsedData.time}'),
                  ),
                  ListTile(
                    title: const Text('Category'),
                    subtitle: Text(receipt.parsedData.category),
                  ),
                  ListTile(
                    title: const Text('Payment Method'),
                    subtitle: Text(receipt.parsedData.paymentMethod.toUpperCase()),
                  ),
                  if (receipt.parsedData.items.isNotEmpty) ...[
                    AppSpacing.vMd,
                    const Text('Items list:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...receipt.parsedData.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.name),
                            Text('₹${item.price.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  AppSpacing.vLg,
                  const Text('Recognized OCR Text:', style: TextStyle(fontWeight: FontWeight.bold)),
                  AppSpacing.vSm,
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        receipt.ocrText,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                  AppSpacing.vLg,
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ref.read(receiptScannerControllerProvider.notifier).deleteReceipt(receipt.id);
                          },
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () async {
                            final router = GoRouter.of(context);
                            final parsed = receipt.parsedData;
                            final categories =
                                (ref.read(categoryControllerProvider).value ?? [])
                                    .cast<Category>()
                                    .toList();

                            // Same name/category checkpoint as a fresh scan, so
                            // re-filing an old receipt doesn't land uncategorised
                            // (and therefore invisible in the category charts).
                            final confirmed =
                                await showDialog<ConfirmedExpenseDetails>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => ExpenseConfirmDialog(
                                detectedTitle: parsed.merchantName,
                                detectedCategoryName: parsed.category,
                                amount: parsed.totalAmount,
                                categories: categories,
                                confidence: parsed.confidenceScore,
                              ),
                            );
                            if (confirmed == null) return;

                            final preFilled = Expense(
                              id: '',
                              userId: '',
                              title: confirmed.title,
                              amount: parsed.totalAmount,
                              categoryId: confirmed.category?.id,
                              accountId: null,
                              paymentMethod: PaymentMethod.fromWire(parsed.paymentMethod),
                              transactionType: TransactionType.expense,
                              notes: 'Extracted from receipt. Bill #${receipt.id.substring(0, 8)}',
                              transactionDate: parsed.date,
                            );

                            if (context.mounted) Navigator.of(context).pop();
                            router.go(Routes.addExpense, extra: preFilled);
                          },
                          child: const Text('Add Transaction'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptReviewSheet extends ConsumerStatefulWidget {
  const _ReceiptReviewSheet({
    required this.imagePath,
    required this.initialData,
    required this.onDone,
  });

  final String imagePath;
  final ReceiptData initialData;
  final VoidCallback onDone;

  @override
  ConsumerState<_ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends ConsumerState<_ReceiptReviewSheet> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _taxController;
  late final TextEditingController _discountController;

  late String _category;
  late String _paymentMethod;
  late DateTime _selectedDate;
  late List<ReceiptItem> _items;
  bool _isDuplicate = false;

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  InputDecoration _getItemInputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _merchantController = TextEditingController(text: d.merchantName);
    _amountController = TextEditingController(text: d.totalAmount.toStringAsFixed(2));
    _selectedDate = d.date;
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(d.date));
    _timeController = TextEditingController(text: d.time);
    _taxController = TextEditingController(text: d.tax.toStringAsFixed(2));
    _discountController = TextEditingController(text: d.discount.toStringAsFixed(2));
    _category = d.category;
    _paymentMethod = d.paymentMethod;
    _items = List.from(d.items);

    _checkDuplicate();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  /// The category whose name matches the scanner's guess, or null when there
  /// is no match. Never falls back to an arbitrary category.
  Category? _matchCategory(List<Category> categories) {
    final target = _category.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final c in categories) {
      if (c.name.toLowerCase() == target) return c;
    }
    return null;
  }

  Future<void> _checkDuplicate() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final res = await ref.read(receiptScannerControllerProvider.notifier).checkDuplicate(
          amount,
          _selectedDate,
          _merchantController.text,
        );
    if (mounted) {
      setState(() {
        _isDuplicate = res;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
      _checkDuplicate();
    }
  }

  Color _getConfidenceColor(double score) {
    if (score >= 0.85) return Colors.greenAccent;
    if (score >= 0.70) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.initialData;
    final categories = (ref.watch(categoryControllerProvider).value ?? []).cast<Category>().toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              AppSpacing.vLg,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Verify Extracted Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(d.confidenceScore).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getConfidenceColor(d.confidenceScore)),
                    ),
                    child: Text(
                      '${(d.confidenceScore * 100).toStringAsFixed(0)}% Match',
                      style: TextStyle(color: _getConfidenceColor(d.confidenceScore), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              AppSpacing.vMd,

              // Duplicate warning
              if (_isDuplicate) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This receipt already exists in database.',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vMd,
              ],

              // Merchant Field
              TextField(
                controller: _merchantController,
                style: const TextStyle(color: Colors.white),
                decoration: _getInputDecoration('Merchant / Store Name'),
                onChanged: (_) => _checkDuplicate(),
              ),
              AppSpacing.vMd,

              // Total Amount
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: _getInputDecoration('Total Amount (₹)'),
                onChanged: (_) => _checkDuplicate(),
              ),
              AppSpacing.vMd,

              // Date Picker
              TextField(
                controller: _dateController,
                readOnly: true,
                style: const TextStyle(color: Colors.white),
                decoration: _getInputDecoration('Transaction Date').copyWith(
                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                ),
                onTap: _selectDate,
              ),
              AppSpacing.vMd,

              // Time
              TextField(
                controller: _timeController,
                style: const TextStyle(color: Colors.white),
                decoration: _getInputDecoration('Transaction Time'),
              ),
              AppSpacing.vMd,

              // Category Selector
              DropdownButtonFormField<String>(
                value: categories.any((cat) => cat.name == _category) ? _category : null,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                decoration: _getInputDecoration('Predicted Category'),
                items: categories
                    .map((cat) => DropdownMenuItem(
                          value: cat.name,
                          child: Text(cat.name),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _category = val;
                    });
                  }
                },
              ),
              AppSpacing.vMd,

              // Payment Method
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                decoration: _getInputDecoration('Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'creditCard', child: Text('Credit Card')),
                  DropdownMenuItem(value: 'debitCard', child: Text('Debit Card')),
                  DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  DropdownMenuItem(value: 'bankTransfer', child: Text('Bank Transfer')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _paymentMethod = val;
                    });
                  }
                },
              ),
              AppSpacing.vMd,

              // Tax & Discount
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taxController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _getInputDecoration('Tax / GST (₹)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _getInputDecoration('Discount (₹)'),
                    ),
                  ),
                ],
              ),
              AppSpacing.vLg,

              // Items Header
              const Text('Parsed Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              AppSpacing.vSm,

              // Items List
              if (_items.isEmpty)
                const Text('No individual items parsed.', style: TextStyle(color: Colors.grey, fontSize: 13))
              else
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: item.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _getItemInputDecoration(),
                            onChanged: (val) {
                              _items[idx] = ReceiptItem(name: val, price: item.price);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: item.price.toStringAsFixed(2),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _getItemInputDecoration(),
                            onChanged: (val) {
                              final price = double.tryParse(val) ?? 0.0;
                              _items[idx] = ReceiptItem(name: item.name, price: price);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              AppSpacing.vLg,

              // Actions
              Row(
                children: [
                  Expanded(
                    child: FinoraButton(
                      label: 'Save Receipt',
                      onPressed: () async {
                        final parsed = ReceiptData(
                          merchantName: _merchantController.text.trim(),
                          totalAmount: double.tryParse(_amountController.text) ?? 0.0,
                          date: _selectedDate,
                          time: _timeController.text.trim(),
                          category: _category,
                          paymentMethod: _paymentMethod,
                          tax: double.tryParse(_taxController.text) ?? 0.0,
                          discount: double.tryParse(_discountController.text) ?? 0.0,
                          items: _items,
                          confidenceScore: d.confidenceScore,
                        );

                        final receipt = Receipt(
                          id: const Uuid().v4(),
                          userId: 'local-user',
                          imagePath: widget.imagePath,
                          ocrText: '',
                          parsedData: parsed,
                          createdAt: DateTime.now(),
                        );

                        await ref.read(receiptScannerControllerProvider.notifier).saveReceipt(receipt);
                        widget.onDone();
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Receipt successfully stored in history!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FinoraButton(
                      label: 'Create Expense',
                      onPressed: () async {
                        final parsed = ReceiptData(
                          merchantName: _merchantController.text.trim(),
                          totalAmount: double.tryParse(_amountController.text) ?? 0.0,
                          date: _selectedDate,
                          time: _timeController.text.trim(),
                          category: _category,
                          paymentMethod: _paymentMethod,
                          tax: double.tryParse(_taxController.text) ?? 0.0,
                          discount: double.tryParse(_discountController.text) ?? 0.0,
                          items: _items,
                          confidenceScore: d.confidenceScore,
                        );

                        // Last checkpoint: let the user name the expense and
                        // confirm (or correct) the category the scan guessed,
                        // before any of it is written.
                        String title = parsed.merchantName;
                        Category? chosenCategory = _matchCategory(categories);

                        if (ref.read(settingsProvider).confirmScannedExpense) {
                          final confirmed =
                              await showDialog<ConfirmedExpenseDetails>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => ExpenseConfirmDialog(
                              detectedTitle: parsed.merchantName,
                              detectedCategoryName: parsed.category,
                              amount: parsed.totalAmount,
                              categories: categories,
                              confidence: parsed.confidenceScore,
                            ),
                          );

                          // Backed out — keep them on the review sheet so
                          // nothing is saved behind their back.
                          if (confirmed == null) return;

                          title = confirmed.title;
                          chosenCategory = confirmed.category;
                        }

                        // Save the receipt to scanner history first so it is preserved
                        final receipt = Receipt(
                          id: const Uuid().v4(),
                          userId: 'local-user',
                          imagePath: widget.imagePath,
                          ocrText: '',
                          parsedData: parsed,
                          createdAt: DateTime.now(),
                        );

                        await ref.read(receiptScannerControllerProvider.notifier).saveReceipt(receipt);
                        widget.onDone();

                        final preFilled = Expense(
                          id: '',
                          userId: '',
                          title: title,
                          amount: parsed.totalAmount,
                          categoryId: chosenCategory?.id,
                          accountId: null,
                          paymentMethod: PaymentMethod.fromWire(parsed.paymentMethod),
                          transactionType: TransactionType.expense,
                          notes: parsed.items.isNotEmpty
                              ? 'Items:\n' + parsed.items.map((i) => '- ${i.name}: ₹${i.price.toStringAsFixed(2)}').join('\n')
                              : 'Scanned Receipt',
                          transactionDate: parsed.date,
                        );

                        final router = GoRouter.of(context);
                        if (mounted) {
                          Navigator.of(context).pop(); // Close bottom sheet
                          router.go(Routes.addExpense, extra: preFilled);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
