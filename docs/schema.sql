-- Order Management Hub - Database Schema
-- Run this script in MySQL Workbench to set up the database

CREATE SCHEMA order_management;
USE order_management;

-- ============================================
-- Customer table
-- ============================================
CREATE TABLE cust_data (
    cust_id   VARCHAR(30) PRIMARY KEY,
    cust_name VARCHAR(20),
    email     VARCHAR(30) UNIQUE,
    phone     VARCHAR(15) UNIQUE,
    city      VARCHAR(20)
);

-- ============================================
-- Inventory table
-- ============================================
CREATE TABLE inventory (
    product_id   VARCHAR(10) PRIMARY KEY,
    product_name VARCHAR(20),
    brand        VARCHAR(20),
    category     VARCHAR(20),
    quantity     INTEGER,
    availability BOOLEAN,
    price        DOUBLE
);

-- ============================================
-- Order table
-- ============================================
CREATE TABLE order_table (
    order_id         VARCHAR(10) PRIMARY KEY,
    cust_id          VARCHAR(10),
    order_date       DATE,
    total_order_price DOUBLE,
    exp_del_date     DATE,
    delivery_status  VARCHAR(10),
    FOREIGN KEY (cust_id) REFERENCES cust_data(cust_id)
);

-- ============================================
-- Order items table
-- ============================================
CREATE TABLE order_items (
    order_id    VARCHAR(20),
    product_id  VARCHAR(20),
    quantity    INT,
    order_price DOUBLE,
    FOREIGN KEY (order_id) REFERENCES order_table(order_id),
    FOREIGN KEY (product_id) REFERENCES inventory(product_id)
);

-- ============================================
-- Stored procedure: getProducts
-- Used by GET /product for dynamic filtering by
-- category and/or maxPrice without building SQL
-- dynamically in the integration layer.
-- ============================================
DELIMITER //

CREATE PROCEDURE getProducts(
    IN p_category VARCHAR(50),
    IN p_maxPrice DOUBLE
)
BEGIN
    SELECT * FROM inventory
    WHERE
        (p_category IS NULL OR category = p_category)
        AND (p_maxPrice IS NULL OR price <= p_maxPrice);
END //

DELIMITER ;
