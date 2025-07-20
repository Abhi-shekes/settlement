

# Settlement - Expense Tracking & Bill Splitting App

A comprehensive Flutter application for personal expense tracking, bill splitting with friends, and group expense management. Built with Firebase backend for real-time synchronization and seamless collaboration.

## 📱 Features Overview

### 🔐 Authentication & User Management

- **Google Sign-In Integration**: Secure authentication using Google OAuth
- **Friend System**: Add friends using unique friend codes or email addresses
- **User Profiles**: Manage personal information and view expense statistics


### 💰 Personal Expense Tracking

- **Category-wise Expenses**: Track expenses across 8 predefined categories (Food, Travel, Shopping, Entertainment, Utilities, Healthcare, Education, Other)
- **Expense Management**: Add, edit, delete, and search through personal expenses
- **Tags & Notes**: Organize expenses with custom tags and detailed descriptions
- **Advanced Filtering**: Filter by date range, category, amount, and search terms


### 📊 Budget Management

- **Monthly Budgets**: Set category-wise monthly spending limits
- **Budget Tracking**: Real-time progress tracking with visual indicators
- **Smart Alerts**: Get notified when approaching 80% of budget limit
- **Budget Analytics**: Visual representation of spending vs. budget allocation


### 👥 Group Management

- **Create Groups**: Form expense-sharing groups with friends
- **Role Management**: Admin and member roles with appropriate permissions
- **Group Balances**: Real-time calculation of who owes what to whom
- **Member Management**: Add/remove members, transfer admin rights


### 🧾 Bill Splitting

- **Flexible Split Types**:

- Equal splits among all participants
- Unequal/custom splits with specific amounts per person



- **Group & Personal Splits**: Split bills within groups or with individual friends
- **Split History**: Complete history of all split transactions
- **Settlement Tracking**: Track partial and full settlements


### 💸 Settlement System

- **Two-way Settlement View**:

- **You Owe**: Track amounts you need to pay to others
- **Owed to You**: Monitor amounts others owe you



- **Flexible Settlement Options**:

- Partial settlements with custom amounts
- Full settlement with one click
- Mark payments as received from others



- **Settlement History**: Complete audit trail of all transactions


### 📈 Analytics & Insights

- **Expense Analytics**: Visual charts showing spending patterns
- **Category Breakdown**: Pie charts and bar graphs for expense distribution
- **Time-based Analysis**: Daily, weekly, and monthly spending trends
- **Budget vs. Actual**: Compare planned vs. actual spending


### 🔍 Advanced Search & Filtering

- **Multi-criteria Search**: Search across titles, descriptions, and tags
- **Date Range Filtering**: Custom date range selection
- **Category Filtering**: Filter by single or multiple categories
- **Amount Sorting**: Sort by date, amount, or category


## 🏗️ Technical Architecture

### Frontend

- **Framework**: Flutter 3.1.0+
- **State Management**: Provider pattern for reactive state management
- **UI Components**: Material Design 3 with custom theming
- **Navigation**: Bottom navigation with tab-based architecture


### Backend

- **Database**: Cloud Firestore for real-time data synchronization
- **Authentication**: Firebase Authentication with Google Sign-In
- **Storage**: Firebase Storage for user profile images and group photos
- **Security**: Firestore security rules for data protection


### Key Dependencies

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  google_sign_in: ^6.1.6
  provider: ^6.1.1
  fl_chart: ^0.65.0
  intl: ^0.18.1
  uuid: ^4.2.1
```

## 📊 Database Schema

### Core Collections

#### Users Collection

```plaintext
users/{userId}
├── uid: string
├── email: string
├── displayName: string
├── photoURL: string
├── friendCode: string (8-character unique code)
├── createdAt: timestamp
├── friends: array of user IDs
└── groups: array of group IDs
```

#### Expenses Collection

```plaintext
expenses/{expenseId}
├── id: string
├── userId: string (expense creator)
├── title: string
├── description: string
├── amount: double (in INR)
├── category: enum (food, travel, shopping, etc.)
├── createdAt: timestamp
├── tags: array of strings
├── groupId: string (optional)
└── isSettled: boolean
```

#### Splits Collection

```plaintext
splits/{splitId}
├── id: string
├── title: string
├── description: string
├── totalAmount: double
├── paidBy: string (user ID who paid)
├── participants: array of user IDs
├── splitType: enum (equal, unequal)
├── splitAmounts: map {userId: amount}
├── createdAt: timestamp
├── groupId: string (optional)
├── tags: array of strings
├── notes: string
├── isFullySettled: boolean
└── settlements: array of settlement objects
```

#### Groups Collection

```plaintext
groups/{groupId}
├── id: string
├── name: string
├── description: string
├── adminId: string
├── memberIds: array of user IDs
├── createdAt: timestamp
├── imageUrl: string (optional)
├── expenseIds: array of expense IDs
└── balances: map {userId: balance}
```

#### Budgets Collection

```plaintext
budgets/{budgetId}
├── id: string
├── userId: string
├── category: enum
├── amount: double
├── month: timestamp
├── createdAt: timestamp
└── updatedAt: timestamp
```



This Entity Relationship Diagram shows:

## **Core Entities:**

### **USERS**

- Primary entity storing user authentication and profile data
- Contains friend codes for easy friend discovery
- Maintains arrays of friends and groups for quick access


### **EXPENSES**

- Individual expense records with categorization
- Can be personal or group-related expenses
- Tracks settlement status


### **SPLITS**

- Bill splitting records with flexible split types
- Supports equal and unequal splitting
- Tracks payment status and settlement progress


### **SETTLEMENTS**

- Individual settlement transactions between users
- Links to specific splits for tracking
- Records actual money transfers


### **GROUPS**

- Group management with admin/member roles
- Maintains group balances for quick calculations
- Contains expense and member references


### **BUDGETS**

- Monthly budget tracking per category
- User-specific budget management
- Time-based budget periods


## **Key Relationships:**

1. **User-Centric**: Users create expenses, splits, and manage groups
2. **Group Integration**: Groups contain expenses and splits with member participation
3. **Settlement Tracking**: Splits generate settlements between users
4. **Friend Network**: Users can connect as friends for easy group creation
5. **Budget Management**: Users set category-wise monthly budgets


## **Data Flow:**

1. Users create groups and add friends
2. Group expenses are recorded and can be split
3. Splits generate settlement obligations
4. Users settle amounts through the settlement system
5. Budgets track spending against set limits


## 🚀 Getting Started


### Installation

1. **Clone the repository**

```shellscript
git clone https://github.com/yourusername/settlement-app.git
cd settlement-app
```


2. **Install dependencies**

```shellscript
flutter pub get
```


3. **Firebase Setup**

1. Create a new Firebase project
2. Enable Authentication and Firestore
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place configuration files in appropriate directories
5. Update `lib/firebase_options.dart` with your project configuration



4. **Google Sign-In Setup**

1. Configure OAuth consent screen in Google Cloud Console
2. Add SHA-1 fingerprints for Android
3. Update `android/app/build.gradle` with your application ID



5. **Run the application**

```shellscript
flutter run
```




## 📱 App Structure

### Main Screens

#### 🏠 Dashboard

- **Overview Cards**: Quick stats on total expenses, pending settlements, and budget status
- **Recent Activity**: Latest expenses and settlements
- **Quick Actions**: Fast access to add expense, split bill, or settle up
- **Budget Alerts**: Notifications for budget limits and overages


#### 💳 Expenses Screen

- **Expense List**: Chronological list of all personal expenses
- **Search & Filter**: Advanced filtering by category, date, amount, and tags
- **Category Chips**: Quick filter by expense categories
- **Add/Edit**: Create new expenses or modify existing ones
- **Bulk Operations**: Delete multiple expenses or export data


#### 🧾 Splits Screen

- **Three-tab Interface**:

- **All Splits**: Complete history of all bill splits
- **You Owe**: Outstanding amounts you need to pay
- **Owed to You**: Amounts others owe you



- **Split Details**: Detailed breakdown of each split with participant information
- **Settlement Actions**: Quick settle options for outstanding amounts


#### 👥 Groups Screen

- **Group List**: All groups you're part of with balance summaries
- **Group Details**: Member list, expense history, and settlement status
- **Group Actions**: Add expenses, settle balances, manage members
- **Admin Functions**: Edit group details, add/remove members, transfer admin rights


#### 📊 Analytics Screen

- **Expense Charts**: Visual representation of spending patterns
- **Category Breakdown**: Pie charts showing expense distribution
- **Time-based Analysis**: Monthly and weekly spending trends
- **Budget Comparison**: Actual vs. planned spending analysis
- **Export Options**: Generate reports in various formats


#### 👤 Profile Screen

- **User Information**: Display and edit personal details
- **Friend Management**: View friends list and add new friends
- **Settings**: App preferences and notification settings
- **Data Management**: Export data, clear cache, account deletion


### Settlement System

#### You Owe Tab

- **Outstanding Splits**: List of bills where you owe money
- **Amount Breakdown**: Clear display of remaining amounts per split
- **Settlement Options**:

- **Partial Settlement**: Pay any amount up to the total owed
- **Full Settlement**: Pay the complete outstanding amount



- **Progress Tracking**: Visual indicators showing payment progress
- **Settlement History**: Record of all previous payments


#### Owed to You Tab

- **Pending Collections**: Splits where others owe you money
- **Per-person Breakdown**: Detailed view of who owes what amount
- **Mark as Received**: Record payments received outside the app
- **Flexible Amount Entry**: Accept partial or full payments
- **Payment Tracking**: Monitor settlement progress for each person


## 🔧 Key Functionalities

### Expense Management

```plaintext
// Add new expense
ExpenseModel expense = ExpenseModel(
  id: uuid.v4(),
  userId: currentUser.uid,
  title: "Lunch at Restaurant",
  amount: 450.0,
  category: ExpenseCategory.food,
  createdAt: DateTime.now(),
);
await expenseService.addExpense(expense);
```

### Bill Splitting

```plaintext
// Create equal split
SplitModel split = SplitModel(
  id: uuid.v4(),
  title: "Dinner Bill",
  totalAmount: 1200.0,
  paidBy: currentUser.uid,
  participants: [user1.uid, user2.uid, user3.uid],
  splitType: SplitType.equal,
  splitAmounts: {
    user1.uid: 400.0,
    user2.uid: 400.0,
    user3.uid: 400.0,
  },
);
await groupService.createSplit(split);
```

### Settlement Processing

```plaintext
// Record settlement
SettlementModel settlement = SettlementModel(
  id: uuid.v4(),
  splitId: split.id,
  fromUserId: debtor.uid,
  toUserId: creditor.uid,
  amount: 400.0,
  settledAt: DateTime.now(),
);
await groupService.addSettlement(split.id, settlement);
```

### Budget Management

```plaintext
// Set monthly budget
await budgetService.setBudget(
  ExpenseCategory.food, 
  5000.0  // ₹5000 for food category
);

// Check budget status
double spent = expenseService.getTotalExpenseAmountByCategory(
  ExpenseCategory.food
);
double budget = budgetService.getBudgetForCategory(
  ExpenseCategory.food
)?.amount ?? 0;
double percentage = (spent / budget) * 100;
```

## 🎨 UI/UX Features

### Design System

- **Material Design 3**: Modern, accessible design language
- **Custom Color Scheme**: Teal primary (`#008080`) with coral accent (`#FF7F50`)
- **Responsive Layout**: Optimized for various screen sizes
- **Dark Mode Support**: Automatic theme switching based on system preferences


### User Experience

- **Intuitive Navigation**: Bottom navigation with clear iconography
- **Quick Actions**: Floating action buttons for common tasks
- **Smart Defaults**: Pre-filled forms and intelligent suggestions
- **Offline Support**: Local caching for seamless offline experience
- **Real-time Updates**: Live synchronization across devices


### Accessibility

- **Screen Reader Support**: Semantic labels and descriptions
- **High Contrast**: Accessible color combinations
- **Large Touch Targets**: Minimum 44px touch areas
- **Keyboard Navigation**: Full keyboard accessibility support


## 🔒 Security & Privacy

### Data Protection

- **Firestore Security Rules**: Server-side data validation and access control
- **User Isolation**: Users can only access their own data and shared group data
- **Input Validation**: Client and server-side validation for all user inputs
- **Secure Authentication**: Firebase Authentication with Google OAuth


### Privacy Features

- **Minimal Data Collection**: Only essential data is collected and stored
- **Data Encryption**: All data encrypted in transit and at rest
- **User Control**: Users can export or delete their data at any time
- **No Third-party Tracking**: No analytics or tracking beyond Firebase


## 🚀 Future Enhancements

### Planned Features

- **Multi-currency Support**: Handle expenses in different currencies
- **Receipt Scanning**: OCR-based receipt processing for automatic expense entry
- **Payment Integration**: Direct payment processing through UPI/payment gateways
- **Advanced Analytics**: Machine learning-based spending insights and predictions
- **Expense Categories**: Custom category creation and management
- **Recurring Expenses**: Automated tracking of subscription and recurring payments
- **Export Features**: PDF reports and CSV data export
- **Notification System**: Push notifications for settlements and budget alerts


### Technical Improvements

- **Offline Mode**: Complete offline functionality with sync when online
- **Performance Optimization**: Lazy loading and pagination for large datasets





---

**Settlement App** - Making expense sharing simple, transparent, and hassle-free! 💰✨