// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:uuid/uuid.dart';
// import '../../models/expense_model.dart';
// import '../../models/group_model.dart';
// import '../../services/group_service.dart';
// import '../../services/auth_service.dart';

// class AddGroupExpenseScreen extends StatefulWidget {
//   final GroupModel group;

//   const AddGroupExpenseScreen({super.key, required this.group});

//   @override
//   State<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
// }

// class _AddGroupExpenseScreenState extends State<AddGroupExpenseScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _titleController = TextEditingController();
//   final _descriptionController = TextEditingController();
//   final _amountController = TextEditingController();

//   ExpenseCategory _selectedCategory = ExpenseCategory.food;
//   final _tagController = TextEditingController();
//   bool _isLoading = false;

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _descriptionController.dispose();
//     _amountController.dispose();
//     _tagController.dispose();
//     super.dispose();
//   }

//   Future<void> _saveExpense() async {
//     if (!_formKey.currentState!.validate()) return;

//     final authService = context.read<AuthService>();
//     final groupService = context.read<GroupService>();

//     if (authService.currentUser == null) return;

//     setState(() {
//       _isLoading = true;
//     });

//     final expense = ExpenseModel(
//       id: const Uuid().v4(),
//       userId: authService.currentUser!.uid,
//       title: _titleController.text.trim(),
//       description: _descriptionController.text.trim(),
//       amount: double.parse(_amountController.text),
//       category: _selectedCategory,
//       createdAt: DateTime.now(),
//       groupId: widget.group.id,
//     );

//     try {
//       await groupService.addGroupExpense(widget.group.id, expense);

//       setState(() {
//         _isLoading = false;
//       });

//       if (mounted) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Group expense added successfully!'),
//             backgroundColor: Color(0xFF008080),
//           ),
//         );
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error adding expense: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Add Expense - ${widget.group.name}'),
//         backgroundColor: const Color(0xFF008080),
//         foregroundColor: Colors.white,
//       ),
//       body:
//           _isLoading
//               ? const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF008080)),
//               )
//               : Form(
//                 key: _formKey,
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Group Info
//                       Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF008080).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                             color: const Color(0xFF008080).withOpacity(0.3),
//                           ),
//                         ),
//                         child: Row(
//                           children: [
//                             Container(
//                               width: 50,
//                               height: 50,
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFF008080).withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: const Icon(
//                                 Icons.group,
//                                 color: Color(0xFF008080),
//                                 size: 24,
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     widget.group.name,
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   Text(
//                                     '${widget.group.allMemberIds.length} members',
//                                     style: TextStyle(
//                                       color: Colors.grey[600],
//                                       fontSize: 14,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 24),

//                       // Title
//                       TextFormField(
//                         controller: _titleController,
//                         decoration: const InputDecoration(
//                           labelText: 'Expense Title',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.title),
//                         ),
//                         validator: (value) {
//                           if (value == null || value.trim().isEmpty) {
//                             return 'Please enter a title';
//                           }
//                           return null;
//                         },
//                       ),
//                       const SizedBox(height: 16),

//                       // Amount
//                       TextFormField(
//                         controller: _amountController,
//                         decoration: const InputDecoration(
//                           labelText: 'Amount (₹)',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.currency_rupee),
//                         ),
//                         keyboardType: TextInputType.number,
//                         validator: (value) {
//                           if (value == null || value.trim().isEmpty) {
//                             return 'Please enter an amount';
//                           }
//                           final amount = double.tryParse(value);
//                           if (amount == null || amount <= 0) {
//                             return 'Please enter a valid amount';
//                           }
//                           return null;
//                         },
//                       ),
//                       const SizedBox(height: 16),

//                       // // Category
//                       // DropdownButtonFormField<ExpenseCategory>(
//                       //   value: _selectedCategory,
//                       //   decoration: const InputDecoration(
//                       //     labelText: 'Category',
//                       //     border: OutlineInputBorder(),
//                       //     prefixIcon: Icon(Icons.category),
//                       //   ),
//                       //   items:
//                       //       ExpenseCategory.values.map((category) {
//                       //         return DropdownMenuItem(
//                       //           value: category,
//                       //           child: Text(category.categoryDisplayName),
//                       //         );
//                       //       }).toList(),
//                       //   onChanged: (value) {
//                       //     setState(() {
//                       //       _selectedCategory = value!;
//                       //     });
//                       //   },
//                       // ),
//                       // const SizedBox(height: 16),

//                       // Description
//                       TextFormField(
//                         controller: _descriptionController,
//                         decoration: const InputDecoration(
//                           labelText: 'Description (Optional)',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.description),
//                         ),
//                         maxLines: 3,
//                       ),
//                       const SizedBox(height: 16),

//                       // Save Button
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: _saveExpense,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF008080),
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                           child: const Text(
//                             'Add Group Expense',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//     );
//   }
// }
