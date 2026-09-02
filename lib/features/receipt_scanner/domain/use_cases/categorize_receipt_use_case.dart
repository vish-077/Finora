class CategorizeReceiptUseCase {
  const CategorizeReceiptUseCase();

  String call(String merchantName, [List<String>? itemNames]) {
    final name = merchantName.toLowerCase();
    
    // 1. Merchant Name Checks
    final foodKeywords = [
      'restaurant', 'food', 'cafe', 'starbucks', 'mcdonald', 'kfc', 'diner', 
      'hotel', 'pizza', 'burger', 'coffee', 'bakery', 'sweets', 'bistro', 
      'grill', 'canteen', 'kitchen', 'eats', 'pub', 'bar', 'bbq', 'dining', 
      'subway', 'domino', 'dunkin', 'tea', 'baskin', 'creamery', 'waffle',
      'dhaba', 'biryani', 'curry', 'catering', 'juice', 'sweet', 'restro'
    ];

    if (foodKeywords.any((keyword) => name.contains(keyword))) {
      return 'Food';
    }
    
    final fuelKeywords = ['petrol', 'fuel', 'gas', 'shell', 'oil', 'chevron', 'exxon', 'indian oil', 'hpcl', 'bpcl', 'bunk'];
    if (fuelKeywords.any((keyword) => name.contains(keyword))) {
      return 'Fuel';
    }
    
    final medicalKeywords = ['apollo pharmacy', 'pharmacy', 'medical', 'health', 'clinic', 'drug', 'hospital', 'chemist', 'medicos', 'healthcare'];
    if (medicalKeywords.any((keyword) => name.contains(keyword))) {
      return 'Medical';
    }
    
    final shoppingKeywords = ['amazon', 'shopping', 'walmart', 'flipkart', 'target', 'ebay', 'mall', 'apparel', 'clothing', 'fashion', 'store', 'boutique'];
    if (shoppingKeywords.any((keyword) => name.contains(keyword))) {
      return 'Shopping';
    }
    
    // Note: groceries are also mapped to 'Food' in our default categories list
    final groceryKeywords = ['reliance fresh', 'groceries', 'grocery', 'supermarket', 'mart', 'fresh', 'pantry', 'd-mart', 'spencer', 'more retail', 'grocer'];
    if (groceryKeywords.any((keyword) => name.contains(keyword))) {
      return 'Food';
    }
    
    final billKeywords = ['electricity board', 'electricity', 'bills', 'bill', 'power', 'water', 'gas bill', 'utility', 'telecom', 'broadband', 'recharge'];
    if (billKeywords.any((keyword) => name.contains(keyword))) {
      return 'Bills';
    }
    
    final travelKeywords = ['uber', 'travel', 'taxi', 'ola', 'lyft', 'cab', 'transport', 'flight', 'airline', 'railway', 'irctc', 'metro', 'bus'];
    if (travelKeywords.any((keyword) => name.contains(keyword))) {
      return 'Travel';
    }
    
    final incomeKeywords = ['salary slip', 'salary', 'income', 'paycheck', 'payroll', 'dividend', 'bonus'];
    if (incomeKeywords.any((keyword) => name.contains(keyword))) {
      return 'Income';
    }

    // 2. Item Names Checks (if merchant name didn't match)
    if (itemNames != null && itemNames.isNotEmpty) {
      final foodItemKeywords = [
        'chicken', 'rice', 'coffee', 'tea', 'burger', 'pizza', 'coke', 'fries', 
        'roll', 'sandwich', 'curry', 'water', 'soup', 'salad', 'drink', 'pasta', 
        'noodle', 'paneer', 'masala', 'biryani', 'bread', 'butter', 'milk', 'cheese',
        'sauce', 'egg', 'fish', 'meat', 'chocolate', 'cookie', 'shake', 'juice', 'roti'
      ];
      
      for (final item in itemNames) {
        final itemLower = item.toLowerCase();
        if (foodItemKeywords.any((keyword) => itemLower.contains(keyword))) {
          return 'Food';
        }
      }
    }
    
    return 'Others';
  }
}
