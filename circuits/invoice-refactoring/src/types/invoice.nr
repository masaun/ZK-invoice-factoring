// @dev - The Invoice struct, which store the invoice details
// @dev - "invoice_id": a unique identifier for the invoice, which is retrieved from the API of "Invoicing service" or "ERP systems" via zkTLS protocol.
pub struct Invoice {
    invoice_id: Field,
    amount: Field,
    due_date: Field,
    buyer_id: Field,
}