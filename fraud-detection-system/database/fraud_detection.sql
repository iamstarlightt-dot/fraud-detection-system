-- =====================================================================
--  FRAUD DETECTION SYSTEM - COMPLETE MYSQL SCHEMA + POWER BI VIEWS
-- =====================================================================

-- ---------------------------------------------------------
-- 1. Create Database (Run only once)
-- ---------------------------------------------------------
CREATE DATABASE IF NOT EXISTS fraud_detection
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE fraud_detection;

-- ---------------------------------------------------------
-- 2. Drop Tables (Safe for rebuilding the schema)
-- ---------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS predictions;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS model_performance;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------
-- 3. Create Customers Table
-- ---------------------------------------------------------

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    registration_date DATE,
    total_transactions INT DEFAULT 0,
    total_fraud_cases INT DEFAULT 0,
    risk_score DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------
-- 4. Create Transactions Table
-- ---------------------------------------------------------

CREATE TABLE transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    customer_id INT NOT NULL,
    transaction_date DATETIME NOT NULL,
    transaction_amount DECIMAL(12,2) NOT NULL,
    transaction_hour INT,
    day_of_week INT,
    merchant_category VARCHAR(50),
    transaction_type VARCHAR(50),
    location_match TINYINT,
    device_type VARCHAR(50),
    is_weekend TINYINT,
    is_night TINYINT,
    is_high_risk_category TINYINT,
    amount_vs_avg DECIMAL(10,4),
    transaction_count INT,
    risk_score DECIMAL(5,2),
    is_fraud TINYINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_customer (customer_id),
    INDEX idx_date (transaction_date),
    INDEX idx_fraud (is_fraud),
    INDEX idx_amount (transaction_amount),

    FOREIGN KEY (customer_id) 
        REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------
-- 5. Create Predictions Table
-- ---------------------------------------------------------

CREATE TABLE predictions (
    prediction_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(50) NOT NULL,
    model_name VARCHAR(50) NOT NULL,
    predicted_fraud TINYINT,
    fraud_probability DECIMAL(6,5),
    risk_category VARCHAR(20),
    prediction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_transaction (transaction_id),
    INDEX idx_probability (fraud_probability),

    FOREIGN KEY (transaction_id)
        REFERENCES transactions(transaction_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------
-- 6. Create Model Performance Table
-- ---------------------------------------------------------

CREATE TABLE model_performance (
    model_id INT AUTO_INCREMENT PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL,
    training_date DATETIME,
    accuracy DECIMAL(6,5),
    precision_score DECIMAL(6,5),
    recall_score DECIMAL(6,5),
    f1_score DECIMAL(6,5),
    roc_auc DECIMAL(6,5),
    total_samples INT,
    fraud_samples INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- 7. CREATE POWER BI VIEWS
-- =====================================================================

-- ---------------------------------------------------------
-- View 1: Transaction Summary
-- ---------------------------------------------------------

CREATE OR REPLACE VIEW vw_transaction_summary AS
SELECT 
    t.transaction_id,
    t.customer_id,
    t.transaction_date,
    DATE(t.transaction_date) AS transaction_day,
    t.transaction_amount,
    t.transaction_hour,
    t.day_of_week,
    t.merchant_category,
    t.transaction_type,
    t.device_type,
    t.is_fraud,
    t.risk_score,

    p.model_name,
    p.predicted_fraud,
    p.fraud_probability,
    p.risk_category,

    CASE 
        WHEN t.is_fraud = 1 AND p.predicted_fraud = 1 THEN 'True Positive'
        WHEN t.is_fraud = 0 AND p.predicted_fraud = 0 THEN 'True Negative'
        WHEN t.is_fraud = 0 AND p.predicted_fraud = 1 THEN 'False Positive'
        WHEN t.is_fraud = 1 AND p.predicted_fraud = 0 THEN 'False Negative'
    END AS prediction_category

FROM transactions t
LEFT JOIN predictions p 
    ON t.transaction_id = p.transaction_id
WHERE p.model_name = 'Random Forest';

-- ---------------------------------------------------------
-- View 2: Daily Fraud Summary
-- ---------------------------------------------------------

CREATE OR REPLACE VIEW vw_daily_fraud_summary AS
SELECT 
    DATE(transaction_date) AS date,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_cases,
    ROUND(SUM(is_fraud) / COUNT(*) * 100, 2) AS fraud_rate,
    ROUND(SUM(transaction_amount), 2) AS total_amount,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN transaction_amount ELSE 0 END), 2) AS fraud_amount
FROM transactions
GROUP BY DATE(transaction_date)
ORDER BY date;

-- ---------------------------------------------------------
-- View 3: High Risk Transactions
-- ---------------------------------------------------------

CREATE OR REPLACE VIEW vw_high_risk_transactions AS
SELECT 
    t.transaction_id,
    t.customer_id,
    t.transaction_date,
    t.transaction_amount,
    t.merchant_category,
    t.transaction_type,
    p.fraud_probability,
    p.risk_category,
    t.is_fraud AS actual_fraud
FROM transactions t
JOIN predictions p 
    ON t.transaction_id = p.transaction_id
WHERE p.fraud_probability > 0.7
  AND p.model_name = 'Random Forest'
ORDER BY p.fraud_probability DESC;

-- ---------------------------------------------------------
-- View 4: Customer Risk Profile
-- ---------------------------------------------------------

CREATE OR REPLACE VIEW vw_customer_risk_profile AS
SELECT 
    c.customer_id,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.is_fraud) AS fraud_cases,
    ROUND(SUM(t.is_fraud) / COUNT(t.transaction_id) * 100, 2) AS customer_fraud_rate,
    ROUND(AVG(t.transaction_amount), 2) AS avg_transaction_amount,
    ROUND(MAX(t.transaction_amount), 2) AS max_transaction_amount,
    ROUND(AVG(p.fraud_probability), 4) AS avg_fraud_probability,
    MAX(t.transaction_date) AS last_transaction_date
FROM customers c
JOIN transactions t 
    ON c.customer_id = t.customer_id
LEFT JOIN predictions p 
    ON t.transaction_id = p.transaction_id 
    AND p.model_name = 'Random Forest'
GROUP BY c.customer_id;

-- ---------------------------------------------------------
-- View 5: Model Performance Summary
-- ---------------------------------------------------------

CREATE OR REPLACE VIEW vw_model_performance AS
SELECT 
    model_name,
    MAX(training_date) AS last_training_date,
    accuracy,
    precision_score,
    recall_score,
    f1_score,
    roc_auc,
    total_samples,
    fraud_samples
FROM model_performance
GROUP BY model_name;

-- =====================================================================
-- END OF SCRIPT
-- =====================================================================
