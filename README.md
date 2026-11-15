# Loan Calculator

I vibe-coded this app so we could use it in our company.

Almost every customer we talk to asks about a loan, and the first question is always "how much will it cost me each month?" We never had a quick answer. The customer had to wait while one of us walked to the office, opened the lender's website, logged into our account and filled in a form just to get a quote. It took way too long, and sometimes the moment was gone by the time we came back.

So I built this. The idea is that anyone on the sales team, or the managers, can pull out their phone and give the customer a real number right there, standing between the cars, in the middle of the conversation.

The app is in Hebrew and built around the car and consumer loans we offer through Mimun Yashir: Prime plus a margin, 15,000 to 400,000 ₪, 12 to 100 months.

## What it does

You enter the loan amount, the number of months and the margin over Prime, and the monthly payment shows up straight away. From there you can:

- Switch between the three repayment tracks:
  - **Spitzer (שפיצר)**: the same payment every month. This is what most customers get.
  - **Balloon (בלון)**: interest only each month, and the whole principal at the end.
  - **Grace (גרייס)**: nothing to pay for the first 3 months, then the loan plus the interest that built up is spread over the rest of the term.
- See the total cost and the effective annual cost of credit.
- Turn CPI linkage on or off (it's on by default).
- Flip it around: when a customer says "I can pay 1,500 a month", type that in and the app tells you how much they can borrow.
- Share the result as an image, straight to WhatsApp or wherever, so the customer has it in writing.

## Good to know

- **It works without internet.** You can use it in the yard with bad reception.
- **The Prime rate is typed in by hand.** The default is 4.75% (November 2026). When the Bank of Israel changes it, update it in the app.
- **CPI comes from the Central Bureau of Statistics.** When there's a connection, the app grabs the last 12 months' change in the consumer price index from the CBS public API (`api.cbs.gov.il`, no key needed), at most twice a day. The field shows which month the number is from, for example "הלמ״ס 9/2026". If there's no connection it keeps the last value it had (1.6% before the first fetch). If you type in your own rate, it won't overwrite it.
- **Nothing about customers is sent or saved anywhere.** The CPI request is the only thing the app does online.
- **These are estimates.** The final offer from the lender depends on the customer and can be different. Tell the customer that.

## Running it

It's a native SwiftUI app for iPhone and iPad, iOS 17 or later. You need a Mac with Xcode 16 or newer.

```bash
open native-ios/LoanCalculator.xcodeproj
```

Pick a simulator and press Run.

To put it on a real iPhone, create a file called `native-ios/Local.xcconfig` with your Apple team ID in it. Git ignores this file, so your ID doesn't end up in the repo.

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

The Xcode project is generated from `native-ios/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). If you add or remove files outside Xcode, regenerate it:

```bash
cd native-ios && xcodegen generate
```

### Tests

```bash
cd native-ios
xcodebuild test -project LoanCalculator.xcodeproj -scheme LoanCalculator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

This runs the unit tests for the math and the UI tests that click through the app. To keep the screenshots the UI tests take, put `TEST_RUNNER_SHOTS=/some/folder` in front of the command.

## How the math works

Spitzer is the standard annuity formula:

```
PMT = P × r / (1 − (1 + r)^(−n))

P = loan amount
r = monthly rate = (Prime + margin) / 100 / 12
n = number of months
```

Every track is run month by month: if the loan is CPI-linked the balance is indexed first, then interest is added, then that month's payment is taken off.

The effective annual cost is the rate at which the money the customer actually gets (loan minus fees) equals the present value of all the payments, compounded over a year.

Before trusting it with customers I checked it against numbers I already knew:

| Loan | Rate | Months | Monthly payment |
|---|---|---|---|
| 76,500 ₪ | 9.1% | 60 | 1,591.73 ₪ |
| 20,000 ₪ | 7% | 48 | 478.92 ₪ |
| 50,000 ₪ | 6.7% | 60 | 983.00 ₪ |

I also checked it against Mimun Yashir's own published example: 30,000 ₪ at 8.5% over 55 payments with a 490 ₪ fee comes to 660.51 ₪ a month, 36,817 ₪ in total, and an effective cost of 9.66%. The app doesn't ask for a fee anymore, but the calculation still supports one so this check keeps passing.

## Project layout

```
native-ios/
  project.yml               XcodeGen definition
  LoanCalculator/           the app: calculations, state, screens
  LoanCalculatorTests/      unit tests
  LoanCalculatorUITests/    UI tests
```

