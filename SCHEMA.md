# Bank Database Schema

## Entity Relationship Diagram

```mermaid
erDiagram
    branches {
        int       branch_id    PK
        varchar   branch_name
        varchar   address
        varchar   city
        char      state
        varchar   zip_code
        varchar   phone
        date      opened_at
    }

    employees {
        int       employee_id  PK
        int       branch_id    FK
        varchar   first_name
        varchar   last_name
        varchar   role
        varchar   email
        date      hired_at
    }

    customers {
        int         customer_id   PK
        varchar     first_name
        varchar     last_name
        varchar     email
        varchar     phone
        date        date_of_birth
        varchar     address
        varchar     city
        char        state
        varchar     zip_code
        boolean     kyc_verified
        timestamptz created_at
    }

    accounts {
        int         account_id     PK
        int         customer_id    FK
        varchar     account_number
        varchar     account_type
        numeric     balance
        numeric     credit_limit
        char        currency
        varchar     status
        timestamptz opened_at
    }

    cards {
        int     card_id     PK
        int     account_id  FK
        varchar card_type
        varchar card_number
        date    expiry_date
        varchar status
        date    issued_at
    }

    transactions {
        int         transaction_id   PK
        int         account_id       FK
        varchar     transaction_type
        numeric     amount
        numeric     balance_after
        varchar     description
        varchar     reference_number
        varchar     status
        timestamptz created_at
    }

    transfers {
        int         transfer_id      PK
        int         from_account_id  FK
        int         to_account_id    FK
        int         transaction_id   FK
        numeric     amount
        varchar     note
        timestamptz created_at
    }

    loans {
        int     loan_id             PK
        int     customer_id         FK
        int     account_id          FK
        varchar loan_type
        numeric principal_amount
        numeric interest_rate
        int     term_months
        numeric monthly_payment
        numeric outstanding_balance
        varchar status
        date    disbursed_at
        date    next_due_date
    }

    branches     ||--o{ employees    : "employs"
    customers    ||--o{ accounts     : "owns"
    accounts     ||--o{ cards        : "issues"
    accounts     ||--o{ transactions : "records"
    accounts     ||--o{ transfers    : "sends from"
    accounts     ||--o{ transfers    : "receives to"
    transactions ||--o| transfers    : "backs"
    customers    ||--o{ loans        : "borrows"
    accounts     ||--o{ loans        : "disburses to"
```

## Table Summary

| Table | Rows (seed) | Description |
|---|---|---|
| `branches` | 5 | Bank branch locations |
| `employees` | 10 | Staff assigned to branches |
| `customers` | 20 | Individual bank customers |
| `accounts` | 30 | Checking, Savings, Credit, Business accounts |
| `cards` | 16 | Debit and credit cards per account |
| `transactions` | 68 | Every financial event on an account |
| `transfers` | 4 | Internal transfers linking two accounts |
| `loans` | 8 | Mortgage, personal, auto, and business loans |

## Key Relationships

- A **branch** employs many **employees**
- A **customer** owns one or more **accounts**
- An **account** can have many **cards**, **transactions**, and **loans**
- A **transfer** links two accounts (`from` → `to`) and is backed by a **transaction** record
- A **loan** is tied to both a **customer** (borrower) and an **account** (disbursement target)
