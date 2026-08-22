# Fahari Setup

Fahari is a standalone loan management system using the current production feature set. It has its own GitHub repository, Supabase project, browser storage, storage buckets, database helper functions, registration function, and Daraja callback functions.

## Project

- GitHub: `https://github.com/okana123456/Fahari`
- Supabase project ref: `mvgpngbwlrhhzzxwiqrt`
- Supabase URL: `https://mvgpngbwlrhhzzxwiqrt.supabase.co`

## C2B callback URLs

- Validation: `https://mvgpngbwlrhhzzxwiqrt.supabase.co/functions/v1/fahari-c2b-validation`
- Confirmation: `https://mvgpngbwlrhhzzxwiqrt.supabase.co/functions/v1/fahari-payment-callback`

## Database installation

Run `supabase/sql/fahari-complete-install.sql` once in the new Fahari SQL Editor.

## Edge Functions

Deploy these function folders using their folder names:

- `fahari-c2b-validation`
- `fahari-payment-callback`
- `register-fahari-business`
- `register-daraja`
- `start-service-payment`
- `service-payment-callback`
- `service-daraja-diagnostics`

## Required secrets

- `FAHARI_PROJECT_URL`
- `FAHARI_ANON_KEY`
- `FAHARI_SERVICE_ROLE_KEY`
- `FAHARI_REGISTRATION_KEY`
- `SERVICE_BILLING_AMOUNT=3000`

The initial Fahari trial runs through August 2026. The first subscription reminder appears on September 2, 2026, and the normal lock date is September 4 when the month is unpaid.

Service subscription Daraja secrets, when billing is enabled:

- `SERVICE_CONSUMER_KEY`
- `SERVICE_CONSUMER_SECRET`
- `SERVICE_SHORTCODE`
- `SERVICE_PASSKEY`
- `SERVICE_TRANSACTION_TYPE`
- `SERVICE_DARAJA_ENVIRONMENT`
- `SERVICE_CALLBACK_URL`

Business C2B credentials are entered from Fahari Settings and saved in the protected `fahari_daraja_credentials` table. They must never be added to `index.html`.

## Frontend key

The Fahari anon/public key is configured in `index.html`. Never place the service-role key in the frontend.
