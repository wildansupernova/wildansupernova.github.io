---
layout: post
author: Wildan Alnatara
title: How to Implement Idempotent APIs Properly
date: 2025-05-12
categories: [API Design, Backend Development]
tags: [idempotency, rest-api, distributed-systems, reliability]
mermaid: true
auto_number_headers: true
---

# Introduction

Imagine a scenario where you're transferring money from your bank account to another account. During the transfer, a network problem causes a timeout, and as a user, you click the "Transfer" button again. The second attempt succeeds, but to your horror, you discover your account has been debited twice for the same transaction. This unpleasant experience is exactly what API idempotency aims to prevent.

In distributed systems and APIs, idempotency ensures that multiple identical requests have the same effect as a single request. This property is crucial for building reliable systems, especially when handling financial transactions, order submissions, or any operation where duplicates could cause serious problems.

In this article, we'll explore how to properly implement idempotent APIs to safeguard your systems against unintended duplicate operations.

# Understanding Idempotency

## What Makes an API Idempotent?

An idempotent API exhibits several key characteristics:

1. **Same Outcome Guarantee**: Multiple identical requests produce the same state as a single request would have produced.
2. **Safe Repetition**: Requests can be safely repeated without causing unintended side effects. This means identical request should not change or add any additional behavior to the resource that previously touched or created. E.g If I request identical create payment API five times, then payment should only be created once.

## Idempotency by HTTP Method

HTTP methods have inherent idempotency properties:

| Method | Idempotent? | Notes |
|--------|-------------|-------|
| GET    | Yes         | Retrieving data has no side effects |
| HEAD   | Yes         | Similar to GET but returns only headers |
| OPTIONS| Yes         | Returns communication options |
| PUT    | Yes         | Replaces target resource with the request payload |
| DELETE | Yes         | Resource remains deleted after first successful call |
| POST   | No          | Generally creates new resources/entries with each call |
| PATCH  | No*         | Depends on the implementation (*can be made idempotent) |

Understanding these properties is essential for designing reliable APIs, especially in distributed systems where network failures and retries are common occurrences.

# Why Idempotency Matters

## Reliability in Unreliable Environments

Network failures are inevitable in distributed systems. Connections drop, requests timeout, and responses get lost. Without idempotency, each retry attempt could potentially:

- Create duplicate records
- Process payments multiple times
- Apply the same state change repeatedly

## Technical Implementation Challenges

To visualize the challenges of non-idempotent operations in distributed systems, consider this scenario:

```mermaid
sequenceDiagram
    title Order Processing Without Idempotency
    
    participant Client as Client App
    participant Gateway as API Gateway
    participant Order as Order Service
    participant DB as Database

    Client->>Gateway: POST /orders
    activate Gateway
    Gateway->>Order: Create order request
    activate Order
    Order->>DB: Insert new order
    DB-->>Order: Success
    Order-->>Gateway: Order created

    Note over Gateway: Network timeout<br/>before response received
    Gateway->>Order: Retry - Create order request
    Order->>DB: Insert new order (again!)
    DB-->>Order: Success
    Order-->>Gateway: Order created (duplicate)

    Gateway-->>Client: 201 Created
    deactivate Gateway
    deactivate Order

    Note right of DB: Two identical orders<br/>created for single request!
```

With proper idempotency implementation, this scenario would be prevented:

```mermaid
sequenceDiagram
    title Order Processing With Idempotency
    
    participant Client as Client App
    participant Gateway as API Gateway
    participant Order as Order Service
    participant DB as Database

    Client->>Gateway: POST /orders<br/>(Idempotency-Key: uuid-456)
    activate Gateway
    Gateway->>Order: Create order with key uuid-456
    activate Order
    Order->>DB: Insert order with unique key uuid-456
    DB-->>Order: Success (Order ID: 12345)
    Order-->>Gateway: Order created (ID: 12345)

    Note over Gateway: Network timeout<br/>before response received
    Gateway->>Order: Retry - Create order with key uuid-456
    Order->>DB: Insert order with unique key uuid-456
    DB-->>Order: Duplicate key exception
    Note right of Order: Duplicate key detected,<br/>fetch existing order
    Order->>DB: SELECT order by key uuid-456
    DB-->>Order: Return order ID: 12345
    Order-->>Gateway: Order already exists (ID: 12345)

    Gateway-->>Client: 201 Created (Order ID: 12345)
    deactivate Gateway
    deactivate Order

    Note right of DB: Only one order created<br/>race condition avoided!
```

These diagrams illustrate why idempotency is crucial for maintaining data integrity during network failures or client retries.

# Implementation Strategies 

## Using Idempotency Keys

When discussing "identical requests," we need a reliable mechanism to identify them. This is where idempotency keys come in.

An idempotency key is a unique identifier associated with a specific client request that allows the server to detect and handle duplicate requests properly. Here's how it works:

1. **Client Responsibility**: The client generates a unique idempotency key (typically a UUID with sufficient entropy to avoid collisions)
2. **Request Header**: The key is included in the request header, often as `Idempotency-Key` or `X-Idempotency-Key`
3. **Server Processing**: The server uses this key to determine if it's processing a new request or a retry of a previous request

Example request:

<details>
<summary>Click to view example HTTP request</summary>

<pre><code class="language-http">POST /api/payments HTTP/1.1
Host: example.com
Content-Type: application/json
Idempotency-Key: 123e4567-e89b-12d3-a456-426614174000

{
  "amount": 100.00,
  "currency": "USD",
  "destination": "account-456"
}
</code></pre>

</details>

## When Should Clients Regenerate Idempotency Keys?

For user-facing APIs, idempotency key generation is typically guided by the application's user experience. If a create payment request consistently results in timeouts or server errors, redirecting the user to the payments dashboard allows them to verify whether the payment was created. If the payment does not appear in the dashboard after a reasonable delay, it is generally safe to generate a new idempotency key and retry the operation.
From an API system perspective, such as with Stripe's Create Payment API, the idempotency key is often derived from an internal identifier generated by your database and then passed in the Stripe API's idempotency key header. This approach ensures that the same key is used for all retries until the request succeeds.

# Approaches

In this section, I will give you some of the implementation approaches that I have found during my careers as software engineer and also common pitfalls. But before that I want to define API requirements and here I will simulate `POST /api/payments` API idempotency handling.

## API Requirements

- The client must send a `POST /api/payments` request with both an idempotency key and an API key for authentication.

<details>
<summary>Click to view API request/response example</summary>

<pre><code class="language-http">POST /api/payments HTTP/1.1
Host: example.com
Content-Type: application/json
Idempotency-Key: 123e4567-e89b-12d3-a456-426614174000
Api-Key: Merchant-Server-Key-5fc07d0d-3469-46a7-9e76-029c1c4cb002

Request Body:
{
  "amount": 100.00,
  "currency": "USD",
  "destination": "account-456"
}

Response:
{
    "payment_id": "payment-id-1"
}
</code></pre>

</details>

- The API must allow clients to retry requests with the same idempotency key during network instability or server errors, ensuring no duplicate payments occur. Each identical request with the same idempotency key is processed as a single operation.
- If a subsequent request arrives with the same idempotency key but a different payload or different user, the system must respond with HTTP 409 Conflict.


## Approach 1 - Using Redis

In my experience, many engineers instinctively turn to Redis as a solution for this problem. While not inherently wrong, it's often implemented incorrectly. Let's examine a common example:

```python
class PaymentController:
    # redis & db initiated
    def create_payment(self, idempotency_key, amount, currency, source_wallet, destination):
        if self.redis.is_exist(idempotency_key):
            raise DuplicateKeyException()
        value = ""
        time_to_live_seconds = 84600
        self.redis.set(idempotency_key, value, time_to_live_seconds)
        response = self.db.save_payment(amount, currency, source_wallet, destination)
        self.redis.set(idempotency_key, response, time_to_live_seconds)
```

What's the flaw in the code above? If you identified the race condition around `if self.redis.is_exist(idempotency_key):`, you're correct. Imagine two simultaneous requests checking for the key's existence. Since the key hasn't been set yet, neither request triggers the error, both proceed to set the idempotency key to an empty string, and the payment gets duplicated. Shockingly, I encountered this similar code running in production, written by another engineer.

How can we solve this? Redis provides atomic operations, meaning commands like [SETNX](https://redis.io/docs/latest/commands/setnx/) (Set if Not Exists) are executed in a single step, preventing race conditions. By using SETNX, we ensure that only the first request with a given idempotency key will proceed, and any subsequent requests with the same key will be safely ignored or handled as duplicates.

Here's how you can revise the code to use SETNX for atomic idempotency key handling:
