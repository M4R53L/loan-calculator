# Bank Loan Calculator

Flutter app that calculates bank loan payments with Israeli bank interest rates (Prime + Margin).

## Features
- Calculate monthly payments using standard amortization
- Support for Prime + Margin rate structure
- Full amortization schedule with month-by-month breakdown
- Hebrew UI with ILS currency formatting
- Input validation and error handling
- Comprehensive unit tests

## Getting Started

### Prerequisites
- Flutter SDK 3.0 or higher
- iOS/Android development environment

### Installation

1. Create a new Flutter project:
        flutter create loan_calculator
        cd loan_calculator

2. Replace the files with the provided code

3. Get dependencies: flutter pub get

4. Run the app:
        For Android
        flutter run

        For iOS
        flutter run -d ios

        For web (testing)
        flutter run -d chrome

### Run Tests
    flutter test


## Usage

1. Enter loan principal amount in ILS
2. Enter Prime rate (Bank of Israel base rate)
3. Enter Margin rate (bank's additional interest)
4. Enter number of months
5. Tap "חשב" to calculate
6. Toggle "הצג לוח סילוקין" to see amortization schedule

## Formula
Monthly Payment (PMT):
        PMT = P × r / (1 − (1 + r)^(−n))

        Where:
        P = Principal
        r = Monthly rate = (Prime + Margin) / 100 / 12
        n = Number of months

## Test Cases
From the original spreadsheet:
- ₪76,500 @ 9.1% for 60 months → ₪1,591.73/month
- ₪20,000 @ 7% for 48 months → ₪478.92/month
- ₪50,000 @ 6.7% for 60 months → ₪983.00/month

# How to Build and Deploy
1. Android
        # Debug APK
        flutter build apk

        # Release APK
        flutter build apk --release

        # App Bundle (for Play Store)
        flutter build appbundle --release

2. iOS
        # Open Xcode project
        open ios/Runner.xcworkspace

        # Build from command line
        flutter build ios --release

        # For App Store
        flutter build ipa


# Project Structure
                loan_calculator/
                ├── README.md
                ├── lib
                │   ├── main.dart
                │   ├── models
                │   │   └── loan_result.dart
                │   ├── screens
                │   │   └── calculator_screen.dart
                │   └── services
                │       └── loan_calculator.dart
                ├── pubspec.yaml
                └── test
                └── loan_calculator_test.dart
