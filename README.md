# Order Management Integration Hub

A MuleSoft-based REST API for managing customers, inventory, and orders for an e-commerce-style order management system. Built with Anypoint Studio, MySQL, and a spec-first (RAML) design approach, with a full MUnit test suite covering success paths, validation errors, and transactional rollback scenarios.

This project was built as a hands-on portfolio piece to apply MuleSoft integration concepts including API-led connectivity, DataWeave transformations, transactional error handling, dynamic SQL via stored procedures, and MUnit testing patterns.

---

## Tech Stack

- **MuleSoft Anypoint Studio** (Mule 4)
- **RAML** — spec-first API design via APIkit Router
- **MySQL** — relational database with a stored procedure for dynamic filtering
- **DataWeave 2.0** — data transformations
- **MUnit** — automated testing with mocking, Object Store-based iteration mocking, and transactional rollback testing
- **SMTP (Mailtrap)** — order confirmation emails

---

## Features

- Customer registration with duplicate email/phone detection
- Product catalog management (add, update, restock)
- Inventory stock status reporting (in stock / low stock / out of stock)
- Order placement with:
  - Stock validation
  - Dynamic delivery time estimation based on customer city
  - Delivery rejection for out-of-region cities
  - Atomic transactions — if any step fails, all database changes are rolled back
  - Order confirmation email
- Order history retrieval with optional filtering by order ID
- Order delivery status updates

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/addCust` | Register a new customer |
| POST | `/api/product` | Add a new product to inventory |
| GET | `/api/product` | Get products, optionally filtered by `category` and/or `maxPrice` |
| GET | `/api/product/{productId}` | Get a single product by ID |
| PUT | `/api/product/{productId}` | Update product details |
| PUT | `/api/product/{productId}/restock` | Increase product stock quantity |
| GET | `/api/product/stockStatus` | Get inventory grouped by stock status, optionally filtered by `status` |
| POST | `/api/order` | Place a new order |
| GET | `/api/order/{custId}` | Get a customer's orders, optionally filtered by `orderId` |
| PUT | `/api/order/{orderId}/status` | Update an order's delivery status |

---

## Setup Instructions

### Prerequisites

- Anypoint Studio (Mule 4 runtime)
- MySQL Server 8.0+ and MySQL Workbench
- An Anypoint Platform account (the RAML spec is referenced from Anypoint Exchange)
- A Mailtrap account (or any SMTP provider) for email testing

### 1. Clone the repository

```bash
git clone https://github.com/Anurag180259/order_management_hub.git
```

### 2. Import into Anypoint Studio

`File → Import → Anypoint Studio → Anypoint Studio Project from External Location`, then select the cloned folder.

Make sure you're logged into Anypoint Platform in Studio (`Preferences → Anypoint Studio → Authentication`) so the RAML spec resolves correctly from Exchange.

### 3. Set up the database

Run the SQL script in `docs/schema.sql` in MySQL Workbench. This creates the `order_management` schema, all required tables (`cust_data`, `inventory`, `order_table`, `order_items`), and the `getProducts` stored procedure used for dynamic product filtering.

### 4. Configure credentials

Copy `configuration.properties.example` to `configuration.properties` in `src/main/resources/` and fill in your own values:

```properties
db.host=localhost
db.port=3306
db.username=root
db.password=yourpassword

smtp.host=sandbox.smtp.mailtrap.io
smtp.port=2525
smtp.username=yourMailtrapUsername
smtp.password=yourMailtrapPassword
```

### 5. Run the project

Right-click the project → `Run As → Mule Application`. The API will be available at `http://localhost:8081/api`.

---

## Testing

The project includes a full MUnit test suite covering:

- Customer registration (success and duplicate-entry scenarios)
- Order placement success path
- Stock quantity exceeded error handling
- Out-of-region delivery rejection
- Transactional rollback on internal errors
- Order retrieval with and without an order ID filter

Run the suite via `Run As → MUnit Test` in Anypoint Studio.

**Note on testing `For Each` loops:** Several flows iterate over a list of order items, calling the same DB select processor on each iteration. Since `mock-when` returns a static payload, a counter-based pattern using the Object Store was used to return different mock data on successive calls — simulating different products being fetched per iteration within a single test run.

---

## Design Notes

A few deliberate design decisions worth calling out:

- **Transactional integrity** — order placement wraps all related database operations (stock updates, order creation, order item insertion) in a single `ALWAYS_BEGIN` transaction scope, so a failure partway through rolls back everything cleanly.
- **Operation ordering driven by foreign key constraints** — within order placement, stock validation and price calculation happen first (per item), then the order record is created, and only then are order items inserted — because `order_items` has a foreign key on `order_id`, which doesn't exist until the order record itself is created. Wrapping all of this in one transaction avoids leaving an orphaned `order_items` entry if the order record insert fails partway through.
- **Price snapshotting** — `order_items` stores the price of each product at the time the order was placed (`order_price`), rather than relying on a live join to `inventory`. This ensures that if a product's price changes later, historical orders still reflect the price the customer was actually charged.
- **Dynamic filtering via stored procedure** — the `GET /product` endpoint supports optional `category` and `maxPrice` filters. Rather than building SQL dynamically in the integration layer (which risks SQL injection and doesn't scale well as filters grow), filtering logic lives in a MySQL stored procedure (`getProducts`) that conditionally applies each filter based on whether a value was passed.
- **Delivery rejection** — orders to cities outside the supported delivery region return a structured `notDeliverable` error rather than failing silently or with a generic 500.

---

## Known Limitations

- Delivery time estimation is based on the customer's city only, not a full address or pin code — all customers within the same city receive the same estimated delivery time regardless of distance to the fulfillment location. A pin-code-based estimation would be a more accurate next step.
- The API has no authentication or authorization layer — any client can call any endpoint, including operations like adding products or updating order/delivery status that would typically be restricted to authorized users.
- List endpoints (`GET /product`, `GET /order/{custId}`) return all matching records with no pagination — acceptable at this data scale but would need to be addressed for production use.
- The stored procedure currently supports two filters (`category`, `maxPrice`); additional filters would follow the same `IS NULL OR` pattern.

---

## Future Enhancements

Planned directions for future iterations of this project:

- **API-led connectivity** — split the current single API into the standard three-layer architecture: an experience API (consumer-facing), a process API (order orchestration logic currently in `post:\order`), and system APIs for the customer, inventory, and order databases.
- **Payment integration (mock)** — add a mock payment step to order placement, simulating an authorization call before the order is confirmed, including handling for declined/failed payment scenarios.
- **Restock notifications** — if a customer orders a product that's currently low or out of stock, capture their email and notify them automatically once the product is restocked, using the existing SMTP email connector.
- **Decoupled email delivery** — currently, order confirmation emails are sent synchronously (with built-in reconnection retries) as part of the order request. Moving this to a message queue (e.g., RabbitMQ) would fully decouple email delivery from the order response, allowing emails to be retried independently without affecting request latency.

---

## Project Structure

```
order_management_hub/
├── src/main/mule/              # Mule flow XML files
├── src/test/munit/             # MUnit test suites
├── src/main/resources/         # Configuration files
├── docs/
│   ├── ordermanagement.raml    # API specification (reference copy)
│   ├── schema.sql              # Database schema and stored procedure
│   └── dev-notes.md            # Development notes and debugging log
└── pom.xml
```

> **Note:** The API specification (RAML) is included under `docs/` for reference. The live project resolves this spec from Anypoint Exchange.
