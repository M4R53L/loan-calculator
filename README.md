# Bank Loan Calculator

A Hebrew loan calculator for Israeli consumer and car loans, priced as Prime plus a margin. The limits and repayment tracks follow the loans Mimun Yashir offers: 15,000 to 400,000 ₪ over 12 to 100 months.

It is a native SwiftUI app for iPhone and iPad, iOS 17 or later, in `native-ios/`.

It works offline. The Prime rate is a number you type in; the default is 4.75%, as of November 2026.

The one thing it fetches is the consumer price index, from the Central Bureau of Statistics' public API (`api.cbs.gov.il`, no key needed), at most twice a day. The CPI-linkage field then starts at the change over the last 12 months, labelled with the month it is for, such as "הלמ״ס 9/2026". Nothing is sent. Without a connection the field keeps its last value, 3% before the first fetch, and a rate you type yourself is never replaced.

## What it calculates

- **Monthly payment** for a loan amount, term and rate
- **Repayment tracks**
  - Spitzer (שפיצר): the same payment every month
  - Balloon (בלון): interest only each month, the whole principal in the last payment
  - Grace (גרייס): no payments for the first 3 months, then the loan and the accrued interest over the rest of the term
- **Effective annual cost of credit**
- **CPI linkage**, on by default, from the published 12-month CPI change or an inflation rate you estimate
- **How much can I borrow**: enter the monthly payment you can afford and get the loan amount
- **Share as an image**: a PNG of the result, drawn in the app's own design, through the share sheet

## Running the app

Requires Xcode 16 or later.

```bash
open native-ios/LoanCalculator.xcodeproj
```

Pick a simulator and press Run.

To run on a real iPhone, create `native-ios/Local.xcconfig` with your Apple team ID. Git ignores this file, so the ID stays out of the repo.

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

The Xcode project is generated from `native-ios/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding or removing files outside Xcode, regenerate it:

```bash
cd native-ios && xcodegen generate
```

## Tests

```bash
cd native-ios
xcodebuild test -project LoanCalculator.xcodeproj -scheme LoanCalculator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

This runs the unit tests for the calculations and the UI tests that drive the app. To keep screenshots from the UI tests, add `TEST_RUNNER_SHOTS=/some/folder` before `xcodebuild`.

## How the payment is calculated

Spitzer uses the standard annuity formula:

```
PMT = P × r / (1 − (1 + r)^(−n))

P = loan amount
r = monthly rate = (Prime + margin) / 100 / 12
n = number of months
```

Every track is simulated month by month: the balance is indexed for inflation if the loan is CPI-linked, interest is charged on it, and the payment for that track is taken off.

The effective annual cost is the rate at which the money you actually receive (the loan minus the fee) equals the present value of all the payments, compounded to a year.

### Checked against

- 76,500 ₪ at 9.1% for 60 months: 1,591.73 ₪ a month
- 20,000 ₪ at 7% for 48 months: 478.92 ₪ a month
- 50,000 ₪ at 6.7% for 60 months: 983.00 ₪ a month
- Mimun Yashir's published example: 30,000 ₪ at 8.5% over 55 payments with a 490 ₪ fee gives 660.51 ₪ a month, 36,817 ₪ in total, and an effective cost of 9.66%. The app no longer asks for a fee, but the calculation still takes one, to keep this check.

## Layout

```
native-ios/
  project.yml               XcodeGen definition
  LoanCalculator/           app: calculator, store, views
  LoanCalculatorTests/      unit tests
  LoanCalculatorUITests/    UI tests
```

The results are estimates. A lender's actual offer depends on the borrower and can differ.
