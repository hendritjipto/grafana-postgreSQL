-- Switch to the bank database (created by 00-create-databases.sh)
\c bank

-- ============================================================
-- BANK FINANCIAL DATABASE
-- ============================================================

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ============================================================
-- TABLE: branches
-- ============================================================
CREATE TABLE branches (
    branch_id     SERIAL PRIMARY KEY,
    branch_name   VARCHAR(100) NOT NULL,
    address       VARCHAR(200) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    state         CHAR(2)      NOT NULL,
    zip_code      VARCHAR(10)  NOT NULL,
    phone         VARCHAR(20)  NOT NULL,
    opened_at     DATE         NOT NULL DEFAULT CURRENT_DATE
);

-- ============================================================
-- TABLE: employees
-- ============================================================
CREATE TABLE employees (
    employee_id   SERIAL PRIMARY KEY,
    branch_id     INT          NOT NULL REFERENCES branches(branch_id),
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    role          VARCHAR(50)  NOT NULL CHECK (role IN ('Manager','Teller','Loan Officer','Compliance Officer')),
    email         VARCHAR(150) NOT NULL UNIQUE,
    hired_at      DATE         NOT NULL
);

-- ============================================================
-- TABLE: customers
-- ============================================================
CREATE TABLE customers (
    customer_id      SERIAL PRIMARY KEY,
    first_name       VARCHAR(50)  NOT NULL,
    last_name        VARCHAR(50)  NOT NULL,
    email            VARCHAR(150) NOT NULL UNIQUE,
    phone            VARCHAR(20),
    date_of_birth    DATE         NOT NULL,
    address          VARCHAR(200),
    city             VARCHAR(100),
    state            CHAR(2),
    zip_code         VARCHAR(10),
    kyc_verified     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: accounts
-- ============================================================
CREATE TABLE accounts (
    account_id     SERIAL PRIMARY KEY,
    customer_id    INT             NOT NULL REFERENCES customers(customer_id),
    account_number VARCHAR(20)     NOT NULL UNIQUE,
    account_type   VARCHAR(20)     NOT NULL CHECK (account_type IN ('Checking','Savings','Credit','Business')),
    balance        NUMERIC(15,2)   NOT NULL DEFAULT 0.00,
    credit_limit   NUMERIC(15,2),
    currency       CHAR(3)         NOT NULL DEFAULT 'USD',
    status         VARCHAR(10)     NOT NULL DEFAULT 'Active' CHECK (status IN ('Active','Closed','Frozen')),
    opened_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: cards
-- ============================================================
CREATE TABLE cards (
    card_id        SERIAL PRIMARY KEY,
    account_id     INT          NOT NULL REFERENCES accounts(account_id),
    card_type      VARCHAR(10)  NOT NULL CHECK (card_type IN ('Debit','Credit')),
    card_number    VARCHAR(19)  NOT NULL UNIQUE,   -- stored masked: **** **** **** 1234
    expiry_date    DATE         NOT NULL,
    status         VARCHAR(10)  NOT NULL DEFAULT 'Active' CHECK (status IN ('Active','Blocked','Expired')),
    issued_at      DATE         NOT NULL DEFAULT CURRENT_DATE
);

-- ============================================================
-- TABLE: transactions
-- ============================================================
CREATE TABLE transactions (
    transaction_id   SERIAL PRIMARY KEY,
    account_id       INT             NOT NULL REFERENCES accounts(account_id),
    transaction_type VARCHAR(20)     NOT NULL CHECK (transaction_type IN ('Deposit','Withdrawal','Transfer','Payment','Fee','Interest')),
    amount           NUMERIC(15,2)   NOT NULL,
    balance_after    NUMERIC(15,2)   NOT NULL,
    description      VARCHAR(255),
    reference_number VARCHAR(30)     NOT NULL UNIQUE DEFAULT 'TXN-' || TO_CHAR(NOW(),'YYYYMMDDHH24MISS') || '-' || FLOOR(RANDOM()*9000+1000)::TEXT,
    status           VARCHAR(10)     NOT NULL DEFAULT 'Completed' CHECK (status IN ('Completed','Pending','Failed','Reversed')),
    created_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: transfers
-- ============================================================
CREATE TABLE transfers (
    transfer_id       SERIAL PRIMARY KEY,
    from_account_id   INT           NOT NULL REFERENCES accounts(account_id),
    to_account_id     INT           NOT NULL REFERENCES accounts(account_id),
    transaction_id    INT           NOT NULL REFERENCES transactions(transaction_id),
    amount            NUMERIC(15,2) NOT NULL,
    note              VARCHAR(255),
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CHECK (from_account_id <> to_account_id)
);

-- ============================================================
-- TABLE: loans
-- ============================================================
CREATE TABLE loans (
    loan_id              SERIAL PRIMARY KEY,
    customer_id          INT             NOT NULL REFERENCES customers(customer_id),
    account_id           INT             REFERENCES accounts(account_id),  -- disbursement account
    loan_type            VARCHAR(20)     NOT NULL CHECK (loan_type IN ('Mortgage','Personal','Auto','Business')),
    principal_amount     NUMERIC(15,2)   NOT NULL,
    interest_rate        NUMERIC(5,2)    NOT NULL,   -- annual %
    term_months          INT             NOT NULL,
    monthly_payment      NUMERIC(15,2)   NOT NULL,
    outstanding_balance  NUMERIC(15,2)   NOT NULL,
    status               VARCHAR(10)     NOT NULL DEFAULT 'Active' CHECK (status IN ('Active','PaidOff','Defaulted','Pending')),
    disbursed_at         DATE,
    next_due_date        DATE
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_accounts_customer    ON accounts(customer_id);
CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_created ON transactions(created_at);
CREATE INDEX idx_transfers_from       ON transfers(from_account_id);
CREATE INDEX idx_transfers_to         ON transfers(to_account_id);
CREATE INDEX idx_loans_customer       ON loans(customer_id);
CREATE INDEX idx_cards_account        ON cards(account_id);
CREATE INDEX idx_employees_branch     ON employees(branch_id);

-- ============================================================
-- DATA: branches
-- ============================================================
INSERT INTO branches (branch_name, address, city, state, zip_code, phone, opened_at) VALUES
('New York Main',        '100 Wall Street',          'New York',    'NY', '10005', '212-555-0100', '2005-03-15'),
('Los Angeles West',     '3800 Wilshire Blvd',       'Los Angeles', 'CA', '90010', '310-555-0200', '2007-06-01'),
('Chicago Downtown',     '200 S Michigan Ave',       'Chicago',     'IL', '60604', '312-555-0300', '2008-11-20'),
('Houston Central',      '910 Travis Street',        'Houston',     'TX', '77002', '713-555-0400', '2010-01-10'),
('Miami Beach',          '1601 Washington Ave',      'Miami Beach', 'FL', '33139', '305-555-0500', '2012-07-04');

-- ============================================================
-- DATA: employees
-- ============================================================
INSERT INTO employees (branch_id, first_name, last_name, role, email, hired_at) VALUES
(1, 'Alice',   'Morgan',   'Manager',            'alice.morgan@claritabank.com',   '2010-05-01'),
(1, 'James',   'Holloway', 'Teller',             'james.holloway@claritabank.com', '2015-08-12'),
(1, 'Sandra',  'Obi',      'Loan Officer',       'sandra.obi@claritabank.com',     '2013-03-22'),
(2, 'Carlos',  'Vega',     'Manager',            'carlos.vega@claritabank.com',    '2009-07-30'),
(2, 'Emily',   'Chen',     'Teller',             'emily.chen@claritabank.com',     '2018-02-14'),
(3, 'Michael', 'Torres',   'Manager',            'michael.torres@claritabank.com', '2011-09-05'),
(3, 'Priya',   'Sharma',   'Compliance Officer', 'priya.sharma@claritabank.com',   '2016-11-01'),
(4, 'David',   'Kim',      'Loan Officer',       'david.kim@claritabank.com',      '2014-04-18'),
(4, 'Fatima',  'Al-Hassan','Teller',             'fatima.alhassan@claritabank.com','2019-06-23'),
(5, 'Robert',  'Nguyen',   'Manager',            'robert.nguyen@claritabank.com',  '2013-08-11');

-- ============================================================
-- DATA: customers
-- ============================================================
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, address, city, state, zip_code, kyc_verified, created_at) VALUES
('John',      'Smith',      'john.smith@email.com',      '212-555-1001', '1985-04-12', '45 Park Ave',         'New York',    'NY', '10016', TRUE,  '2018-01-15 09:00:00+00'),
('Maria',     'Garcia',     'maria.garcia@email.com',    '310-555-1002', '1990-07-22', '801 Sunset Blvd',     'Los Angeles', 'CA', '90028', TRUE,  '2018-03-20 10:30:00+00'),
('Wei',       'Zhang',      'wei.zhang@email.com',       '312-555-1003', '1978-11-03', '330 N Clark St',      'Chicago',     'IL', '60654', TRUE,  '2019-06-01 08:00:00+00'),
('Aisha',     'Johnson',    'aisha.johnson@email.com',   '713-555-1004', '1995-02-17', '2400 Main St',        'Houston',     'TX', '77002', TRUE,  '2019-09-10 14:00:00+00'),
('Lucas',     'Andersen',   'lucas.andersen@email.com',  '305-555-1005', '1982-08-30', '500 Brickell Ave',    'Miami',       'FL', '33131', TRUE,  '2020-01-05 11:00:00+00'),
('Sophie',    'Patel',      'sophie.patel@email.com',    '212-555-1006', '1993-05-14', '10 Fulton St',        'New York',    'NY', '10038', TRUE,  '2020-04-18 09:45:00+00'),
('Daniel',    'Okafor',     'daniel.okafor@email.com',   '312-555-1007', '1988-12-01', '1 S Dearborn St',     'Chicago',     'IL', '60603', FALSE, '2020-07-22 13:00:00+00'),
('Elena',     'Russo',      'elena.russo@email.com',     '305-555-1008', '1975-03-25', '1111 Lincoln Rd',     'Miami Beach', 'FL', '33139', TRUE,  '2021-02-09 10:00:00+00'),
('Omar',      'Farouq',     'omar.farouq@email.com',     '713-555-1009', '1991-09-08', '3100 Main St',        'Houston',     'TX', '77025', TRUE,  '2021-05-14 15:30:00+00'),
('Yuki',      'Tanaka',     'yuki.tanaka@email.com',     '310-555-1010', '1986-06-19', '400 S Hope St',       'Los Angeles', 'CA', '90071', TRUE,  '2021-08-30 09:00:00+00'),
('Carlos',    'Mendoza',    'carlos.mendoza@email.com',  '212-555-1011', '1979-01-27', '250 Broadway',        'New York',    'NY', '10007', TRUE,  '2022-01-11 11:00:00+00'),
('Amara',     'Diallo',     'amara.diallo@email.com',    '713-555-1012', '1997-10-05', '4200 Westheimer Rd',  'Houston',     'TX', '77027', FALSE, '2022-03-15 14:00:00+00'),
('Nathan',    'Brooks',     'nathan.brooks@email.com',   '312-555-1013', '1983-07-14', '875 N Michigan Ave',  'Chicago',     'IL', '60611', TRUE,  '2022-06-20 10:00:00+00'),
('Isabella',  'Ferreira',   'isabella.ferreira@email.com','305-555-1014','1994-04-02', '100 S Biscayne Blvd', 'Miami',       'FL', '33131', TRUE,  '2022-09-01 09:30:00+00'),
('Kevin',     'Park',       'kevin.park@email.com',      '310-555-1015', '1989-11-28', '633 W 5th St',        'Los Angeles', 'CA', '90071', TRUE,  '2023-01-17 08:00:00+00'),
('Nina',      'Kowalski',   'nina.kowalski@email.com',   '212-555-1016', '1992-08-16', '80 Pine St',          'New York',    'NY', '10005', TRUE,  '2023-03-22 12:00:00+00'),
('Hassan',    'Malik',      'hassan.malik@email.com',    '312-555-1017', '1980-02-09', '205 W Wacker Dr',     'Chicago',     'IL', '60606', TRUE,  '2023-06-05 10:30:00+00'),
('Grace',     'Williams',   'grace.williams@email.com',  '713-555-1018', '1996-12-20', '1800 Smith St',       'Houston',     'TX', '77002', TRUE,  '2023-09-12 14:00:00+00'),
('Liam',      'O''Brien',   'liam.obrien@email.com',     '305-555-1019', '1987-05-31', '300 Alton Rd',        'Miami Beach', 'FL', '33139', TRUE,  '2024-01-08 09:00:00+00'),
('Fatou',     'Coulibaly',  'fatou.coulibaly@email.com', '310-555-1020', '1998-03-13', '350 S Grand Ave',     'Los Angeles', 'CA', '90071', FALSE, '2024-04-25 11:00:00+00');

-- ============================================================
-- DATA: accounts
-- ============================================================
INSERT INTO accounts (customer_id, account_number, account_type, balance, credit_limit, currency, status, opened_at) VALUES
-- John Smith
(1,  'ACC-1001-CHK', 'Checking',  12540.75,  NULL,      'USD', 'Active', '2018-01-15 09:05:00+00'),
(1,  'ACC-1002-SAV', 'Savings',   45000.00,  NULL,      'USD', 'Active', '2018-01-15 09:10:00+00'),
-- Maria Garcia
(2,  'ACC-2001-CHK', 'Checking',   8320.50,  NULL,      'USD', 'Active', '2018-03-20 10:35:00+00'),
(2,  'ACC-2002-CRD', 'Credit',    -1250.00,  10000.00,  'USD', 'Active', '2019-01-10 09:00:00+00'),
-- Wei Zhang
(3,  'ACC-3001-BIZ', 'Business',  98700.00,  NULL,      'USD', 'Active', '2019-06-01 08:05:00+00'),
(3,  'ACC-3002-SAV', 'Savings',   22000.00,  NULL,      'USD', 'Active', '2019-06-01 08:10:00+00'),
-- Aisha Johnson
(4,  'ACC-4001-CHK', 'Checking',   3100.00,  NULL,      'USD', 'Active', '2019-09-10 14:05:00+00'),
-- Lucas Andersen
(5,  'ACC-5001-CHK', 'Checking',  17800.25,  NULL,      'USD', 'Active', '2020-01-05 11:05:00+00'),
(5,  'ACC-5002-CRD', 'Credit',    -4500.00,  15000.00,  'USD', 'Active', '2020-06-15 10:00:00+00'),
-- Sophie Patel
(6,  'ACC-6001-SAV', 'Savings',   61000.00,  NULL,      'USD', 'Active', '2020-04-18 09:50:00+00'),
-- Daniel Okafor
(7,  'ACC-7001-CHK', 'Checking',    750.00,  NULL,      'USD', 'Active', '2020-07-22 13:05:00+00'),
-- Elena Russo
(8,  'ACC-8001-CHK', 'Checking',  29450.00,  NULL,      'USD', 'Active', '2021-02-09 10:05:00+00'),
(8,  'ACC-8002-SAV', 'Savings',  105000.00,  NULL,      'USD', 'Active', '2021-02-09 10:10:00+00'),
-- Omar Farouq
(9,  'ACC-9001-CHK', 'Checking',   5600.00,  NULL,      'USD', 'Active', '2021-05-14 15:35:00+00'),
-- Yuki Tanaka
(10, 'ACC-10001-CHK','Checking',  11200.00,  NULL,      'USD', 'Active', '2021-08-30 09:05:00+00'),
(10, 'ACC-10002-CRD','Credit',    -2800.00,  8000.00,   'USD', 'Active', '2022-01-20 09:00:00+00'),
-- Carlos Mendoza
(11, 'ACC-11001-BIZ','Business',  43500.00,  NULL,      'USD', 'Active', '2022-01-11 11:05:00+00'),
-- Amara Diallo
(12, 'ACC-12001-CHK','Checking',   1200.00,  NULL,      'USD', 'Active', '2022-03-15 14:05:00+00'),
-- Nathan Brooks
(13, 'ACC-13001-CHK','Checking',  22300.00,  NULL,      'USD', 'Active', '2022-06-20 10:05:00+00'),
(13, 'ACC-13002-SAV','Savings',   38000.00,  NULL,      'USD', 'Active', '2022-06-20 10:10:00+00'),
-- Isabella Ferreira
(14, 'ACC-14001-CHK','Checking',   9800.00,  NULL,      'USD', 'Active', '2022-09-01 09:35:00+00'),
-- Kevin Park
(15, 'ACC-15001-CHK','Checking',  14600.00,  NULL,      'USD', 'Active', '2023-01-17 08:05:00+00'),
(15, 'ACC-15002-SAV','Savings',   27500.00,  NULL,      'USD', 'Active', '2023-01-17 08:10:00+00'),
-- Nina Kowalski
(16, 'ACC-16001-CHK','Checking',   6450.00,  NULL,      'USD', 'Active', '2023-03-22 12:05:00+00'),
-- Hassan Malik
(17, 'ACC-17001-CHK','Checking',  33100.00,  NULL,      'USD', 'Active', '2023-06-05 10:35:00+00'),
(17, 'ACC-17002-BIZ','Business',  78900.00,  NULL,      'USD', 'Active', '2023-06-05 10:40:00+00'),
-- Grace Williams
(18, 'ACC-18001-CHK','Checking',   4250.00,  NULL,      'USD', 'Active', '2023-09-12 14:05:00+00'),
-- Liam O'Brien
(19, 'ACC-19001-CHK','Checking',  19700.00,  NULL,      'USD', 'Active', '2024-01-08 09:05:00+00'),
(19, 'ACC-19002-SAV','Savings',   52000.00,  NULL,      'USD', 'Active', '2024-01-08 09:10:00+00'),
-- Fatou Coulibaly
(20, 'ACC-20001-CHK','Checking',   2100.00,  NULL,      'USD', 'Active', '2024-04-25 11:05:00+00');

-- ============================================================
-- DATA: cards
-- ============================================================
INSERT INTO cards (account_id, card_type, card_number, expiry_date, status, issued_at) VALUES
(1,  'Debit',  '**** **** **** 4421', '2027-01-31', 'Active',  '2018-01-16'),
(2,  'Debit',  '**** **** **** 8812', '2027-01-31', 'Active',  '2018-01-16'),
(3,  'Debit',  '**** **** **** 3305', '2026-03-31', 'Active',  '2018-03-21'),
(4,  'Credit', '**** **** **** 7741', '2026-12-31', 'Active',  '2019-01-11'),
(5,  'Debit',  '**** **** **** 9920', '2027-06-30', 'Active',  '2019-06-02'),
(7,  'Debit',  '**** **** **** 1134', '2026-09-30', 'Active',  '2019-09-11'),
(8,  'Debit',  '**** **** **** 5567', '2027-01-31', 'Active',  '2020-01-06'),
(9,  'Credit', '**** **** **** 2298', '2025-06-30', 'Expired', '2020-06-16'),
(10, 'Debit',  '**** **** **** 6643', '2027-04-30', 'Active',  '2020-04-19'),
(12, 'Debit',  '**** **** **** 0011', '2026-02-28', 'Active',  '2021-02-10'),
(14, 'Debit',  '**** **** **** 3378', '2027-05-31', 'Active',  '2021-05-15'),
(15, 'Debit',  '**** **** **** 8894', '2027-08-31', 'Active',  '2021-08-31'),
(16, 'Credit', '**** **** **** 4456', '2027-01-31', 'Active',  '2022-01-21'),
(19, 'Debit',  '**** **** **** 7723', '2027-06-30', 'Active',  '2022-06-21'),
(22, 'Debit',  '**** **** **** 5512', '2028-01-31', 'Active',  '2023-01-18'),
(27, 'Debit',  '**** **** **** 9981', '2028-09-30', 'Active',  '2023-09-13');

-- ============================================================
-- DATA: transactions
-- ============================================================
INSERT INTO transactions (account_id, transaction_type, amount, balance_after, description, reference_number, status, created_at) VALUES
-- John Smith - Checking (acc 1)
(1, 'Deposit',    5000.00,  5000.00,  'Initial deposit',            'TXN-20180115-0001', 'Completed', '2018-01-15 09:10:00+00'),
(1, 'Deposit',    3000.00,  8000.00,  'Payroll - Jan 2024',         'TXN-20240101-0001', 'Completed', '2024-01-01 08:00:00+00'),
(1, 'Withdrawal', 500.00,   7500.00,  'ATM withdrawal',             'TXN-20240105-0001', 'Completed', '2024-01-05 11:30:00+00'),
(1, 'Deposit',    3000.00, 10500.00,  'Payroll - Feb 2024',         'TXN-20240201-0001', 'Completed', '2024-02-01 08:00:00+00'),
(1, 'Payment',    850.00,   9650.00,  'Rent payment - Feb 2024',    'TXN-20240205-0001', 'Completed', '2024-02-05 09:00:00+00'),
(1, 'Fee',          25.00,  9625.00,  'Monthly service fee',        'TXN-20240228-0001', 'Completed', '2024-02-28 00:01:00+00'),
(1, 'Deposit',    3000.00, 12625.00,  'Payroll - Mar 2024',         'TXN-20240301-0001', 'Completed', '2024-03-01 08:00:00+00'),
(1, 'Transfer',    -84.25, 12540.75,  'Transfer to savings',        'TXN-20240310-0001', 'Completed', '2024-03-10 14:00:00+00'),

-- John Smith - Savings (acc 2)
(2, 'Deposit',   10000.00, 10000.00,  'Initial savings deposit',    'TXN-20180115-0002', 'Completed', '2018-01-15 09:15:00+00'),
(2, 'Interest',    150.00, 10150.00,  'Annual interest Q1 2024',    'TXN-20240331-0001', 'Completed', '2024-03-31 00:01:00+00'),
(2, 'Transfer',     84.25, 10234.25,  'Transfer from checking',     'TXN-20240310-0002', 'Completed', '2024-03-10 14:01:00+00'),

-- Maria Garcia - Checking (acc 3)
(3, 'Deposit',    4000.00,  4000.00,  'Initial deposit',            'TXN-20180320-0001', 'Completed', '2018-03-20 10:40:00+00'),
(3, 'Deposit',    2800.00,  6800.00,  'Payroll - Jan 2024',         'TXN-20240101-0002', 'Completed', '2024-01-01 08:00:00+00'),
(3, 'Payment',    600.00,   6200.00,  'Utility bills',              'TXN-20240110-0001', 'Completed', '2024-01-10 10:00:00+00'),
(3, 'Deposit',    2800.00,  9000.00,  'Payroll - Feb 2024',         'TXN-20240201-0002', 'Completed', '2024-02-01 08:00:00+00'),
(3, 'Transfer',   -679.50,  8320.50,  'Credit card payment',        'TXN-20240215-0001', 'Completed', '2024-02-15 12:00:00+00'),

-- Maria Garcia - Credit (acc 4)
(4, 'Payment',    679.50,  -1250.00,  'Credit card payment received','TXN-20240215-0002','Completed', '2024-02-15 12:01:00+00'),
(4, 'Fee',         35.00,  -1285.00,  'Late payment fee',           'TXN-20240131-0001', 'Completed', '2024-01-31 00:01:00+00'),

-- Wei Zhang - Business (acc 5)
(5, 'Deposit',   50000.00, 50000.00,  'Business capital injection', 'TXN-20190601-0001', 'Completed', '2019-06-01 08:10:00+00'),
(5, 'Deposit',   25000.00, 75000.00,  'Client payment - Q4 2023',   'TXN-20231201-0001', 'Completed', '2023-12-01 10:00:00+00'),
(5, 'Payment',    8000.00, 67000.00,  'Supplier invoice #4421',     'TXN-20231215-0001', 'Completed', '2023-12-15 14:00:00+00'),
(5, 'Deposit',   38000.00,105000.00,  'Client payment - Q1 2024',   'TXN-20240301-0002', 'Completed', '2024-03-01 09:00:00+00'),
(5, 'Payment',    6300.00, 98700.00,  'Office rent - Mar 2024',     'TXN-20240305-0001', 'Completed', '2024-03-05 10:00:00+00'),

-- Aisha Johnson - Checking (acc 7)
(7, 'Deposit',    2500.00,  2500.00,  'Initial deposit',            'TXN-20190910-0001', 'Completed', '2019-09-10 14:10:00+00'),
(7, 'Deposit',    2200.00,  4700.00,  'Payroll - Feb 2024',         'TXN-20240201-0003', 'Completed', '2024-02-01 08:00:00+00'),
(7, 'Payment',    900.00,   3800.00,  'Rent payment',               'TXN-20240205-0002', 'Completed', '2024-02-05 09:30:00+00'),
(7, 'Withdrawal', 700.00,   3100.00,  'Cash withdrawal',            'TXN-20240220-0001', 'Completed', '2024-02-20 15:00:00+00'),

-- Lucas Andersen - Checking (acc 8)
(8, 'Deposit',   10000.00, 10000.00,  'Initial deposit',            'TXN-20200105-0001', 'Completed', '2020-01-05 11:10:00+00'),
(8, 'Deposit',    4500.00, 14500.00,  'Payroll - Jan 2024',         'TXN-20240101-0003', 'Completed', '2024-01-01 08:00:00+00'),
(8, 'Payment',   1200.00,  13300.00,  'Mortgage payment - Jan',     'TXN-20240115-0001', 'Completed', '2024-01-15 10:00:00+00'),
(8, 'Deposit',    4500.00, 17800.00,  'Payroll - Feb 2024',         'TXN-20240201-0004', 'Completed', '2024-02-01 08:00:00+00'),
(8, 'Payment',    -0.25,   17799.75,  'Interest credit correction', 'TXN-20240228-0002', 'Completed', '2024-02-28 09:00:00+00'),
(8, 'Transfer',    0.50,   17800.25,  'Rounding adjustment',        'TXN-20240229-0001', 'Completed', '2024-02-29 09:00:00+00'),

-- Sophie Patel - Savings (acc 10)
(10,'Deposit',   30000.00, 30000.00,  'Initial savings',            'TXN-20200418-0001', 'Completed', '2020-04-18 09:55:00+00'),
(10,'Deposit',   20000.00, 50000.00,  'Bonus - 2023',               'TXN-20231215-0002', 'Completed', '2023-12-15 12:00:00+00'),
(10,'Interest',   1000.00, 51000.00,  'Annual interest 2023',       'TXN-20231231-0001', 'Completed', '2023-12-31 00:01:00+00'),
(10,'Deposit',   10000.00, 61000.00,  'Bonus - Q1 2024',            'TXN-20240315-0001', 'Completed', '2024-03-15 11:00:00+00'),

-- Elena Russo - Checking (acc 12)
(12,'Deposit',   15000.00, 15000.00,  'Initial deposit',            'TXN-20210209-0001', 'Completed', '2021-02-09 10:10:00+00'),
(12,'Deposit',    5500.00, 20500.00,  'Payroll - Jan 2024',         'TXN-20240101-0004', 'Completed', '2024-01-01 08:00:00+00'),
(12,'Payment',   1800.00,  18700.00,  'Property tax Q1',            'TXN-20240115-0002', 'Completed', '2024-01-15 11:00:00+00'),
(12,'Deposit',    5500.00, 24200.00,  'Payroll - Feb 2024',         'TXN-20240201-0005', 'Completed', '2024-02-01 08:00:00+00'),
(12,'Transfer', -4750.00,  19450.00,  'Transfer to savings',        'TXN-20240210-0001', 'Completed', '2024-02-10 13:00:00+00'),
(12,'Deposit',    5500.00, 24950.00,  'Payroll - Mar 2024',         'TXN-20240301-0003', 'Completed', '2024-03-01 08:00:00+00'),
(12,'Payment',    500.00,  24450.00,  'Insurance premium',          'TXN-20240312-0001', 'Completed', '2024-03-12 10:30:00+00'),
(12,'Withdrawal',5000.00,  19450.00,  'Cash for renovation',        'TXN-20240320-0001', 'Completed', '2024-03-20 14:00:00+00'),
(12,'Deposit',    5500.00, 24950.00,  'Payroll - Apr 2024',         'TXN-20240401-0001', 'Completed', '2024-04-01 08:00:00+00'),
(12,'Payment',    500.00,  24450.00,  'Insurance premium',          'TXN-20240412-0001', 'Completed', '2024-04-12 10:30:00+00'),
(12,'Withdrawal',5000.00,  19450.00,  'Renovation phase 2',         'TXN-20240418-0001', 'Completed', '2024-04-18 14:00:00+00'),

-- Elena Russo - Savings (acc 13)
(13,'Deposit',   50000.00, 50000.00,  'Initial savings',            'TXN-20210209-0002', 'Completed', '2021-02-09 10:15:00+00'),
(13,'Interest',   2000.00, 52000.00,  'Annual interest 2021',       'TXN-20211231-0001', 'Completed', '2021-12-31 00:01:00+00'),
(13,'Interest',   2100.00, 54100.00,  'Annual interest 2022',       'TXN-20221231-0001', 'Completed', '2022-12-31 00:01:00+00'),
(13,'Interest',   2150.00, 56250.00,  'Annual interest 2023',       'TXN-20231231-0002', 'Completed', '2023-12-31 00:01:00+00'),
(13,'Transfer',   4750.00, 61000.00,  'Transfer from checking',     'TXN-20240210-0002', 'Completed', '2024-02-10 13:01:00+00'),

-- Nathan Brooks - Checking (acc 19)
(19,'Deposit',    8000.00,  8000.00,  'Initial deposit',            'TXN-20220620-0001', 'Completed', '2022-06-20 10:10:00+00'),
(19,'Deposit',    3800.00, 11800.00,  'Payroll - Jan 2024',         'TXN-20240101-0005', 'Completed', '2024-01-01 08:00:00+00'),
(19,'Deposit',    3800.00, 15600.00,  'Payroll - Feb 2024',         'TXN-20240201-0006', 'Completed', '2024-02-01 08:00:00+00'),
(19,'Payment',    700.00,  14900.00,  'Car insurance',              'TXN-20240215-0003', 'Completed', '2024-02-15 10:00:00+00'),
(19,'Deposit',    3800.00, 18700.00,  'Payroll - Mar 2024',         'TXN-20240301-0004', 'Completed', '2024-03-01 08:00:00+00'),
(19,'Transfer',  -4400.00, 14300.00,  'Transfer to savings',        'TXN-20240315-0002', 'Completed', '2024-03-15 14:00:00+00'),
(19,'Fee',          25.00, 14275.00,  'Monthly service fee',        'TXN-20240331-0002', 'Completed', '2024-03-31 00:01:00+00'),
(19,'Deposit',    8000.00, 22275.00,  'Bonus payment',              'TXN-20240401-0002', 'Completed', '2024-04-01 10:00:00+00'),
(19,'Withdrawal', 2000.00, 20275.00,  'ATM withdrawal',             'TXN-20240405-0001', 'Completed', '2024-04-05 15:00:00+00'),
(19,'Payment',    1975.00, 18300.00,  'Rent payment - Apr 2024',    'TXN-20240408-0001', 'Completed', '2024-04-08 09:00:00+00'),

-- Nathan Brooks - Savings (acc 20)
(20,'Deposit',   10000.00, 10000.00,  'Initial savings',            'TXN-20220620-0002', 'Completed', '2022-06-20 10:15:00+00'),
(20,'Interest',    500.00, 10500.00,  'Annual interest 2022',       'TXN-20221231-0002', 'Completed', '2022-12-31 00:01:00+00'),
(20,'Interest',    550.00, 11050.00,  'Annual interest 2023',       'TXN-20231231-0003', 'Completed', '2023-12-31 00:01:00+00'),
(20,'Transfer',   4400.00, 15450.00,  'Transfer from checking',     'TXN-20240315-0003', 'Completed', '2024-03-15 14:01:00+00'),
(20,'Interest',    130.00, 15580.00,  'Q1 2024 interest',           'TXN-20240331-0003', 'Completed', '2024-03-31 00:01:00+00');

-- ============================================================
-- DATA: transfers  (links two transaction rows per transfer)
-- ============================================================
INSERT INTO transfers (from_account_id, to_account_id, transaction_id, amount, note, created_at) VALUES
(1,  2,  8,  84.25,  'John Smith: checking to savings',          '2024-03-10 14:00:00+00'),
(3,  4,  16, 679.50, 'Maria Garcia: checking to credit payoff',  '2024-02-15 12:00:00+00'),
(12, 13, 42, 4750.00,'Elena Russo: checking to savings',         '2024-02-10 13:00:00+00'),
(19, 20, 59, 4400.00,'Nathan Brooks: checking to savings',       '2024-03-15 14:00:00+00');

-- ============================================================
-- DATA: loans
-- ============================================================
INSERT INTO loans (customer_id, account_id, loan_type, principal_amount, interest_rate, term_months, monthly_payment, outstanding_balance, status, disbursed_at, next_due_date) VALUES
(1,  1,  'Personal',  15000.00, 7.50,  36,  464.35,  8200.00,  'Active',   '2022-06-01', '2024-04-01'),
(2,  3,  'Auto',      22000.00, 5.99,  60,  424.94,  14500.00, 'Active',   '2021-03-15', '2024-04-15'),
(3,  5,  'Business',  80000.00, 6.25,  84,  1316.43, 52000.00, 'Active',   '2020-09-01', '2024-04-01'),
(5,  8,  'Mortgage', 320000.00, 4.75, 360,  1669.50,295000.00, 'Active',   '2020-02-01', '2024-04-01'),
(8,  12, 'Mortgage', 450000.00, 4.25, 360,  2212.24,410000.00, 'Active',   '2021-03-01', '2024-04-01'),
(10, 15, 'Auto',      18500.00, 6.49,  48,  438.20,   9800.00, 'Active',   '2022-05-10', '2024-04-10'),
(13, 19, 'Personal',  10000.00, 8.99,  24,  456.14,   3200.00, 'Active',   '2023-01-01', '2024-04-01'),
(17, 26, 'Business',  60000.00, 6.75,  60,  1178.11, 48000.00, 'Active',   '2023-07-01', '2024-04-01');
