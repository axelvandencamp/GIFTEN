-----------------------------------------
-- SEPA-Giften
-- opdrachten en facturen
-----------------------------------------
SELECT DISTINCT dpa.id, dpa.partner_id, dpa.analytic_account_id, p.name, /*sm.sm_state sm_state,*/ dpa.interval_type, dpa.interval_number, dpa.donation_amount bedrag, /*ddl.invoice_id, i.state,*/ dpa.next_invoice_date, dpa.donation_start, dpa.last_invoice_date, dpa.donation_cancel,
	ddl.aanmaak_factuur, ddl.amount_total
FROM res_partner p
	JOIN donation_partner_account dpa ON p.id = dpa.partner_id
	JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state, pb.bank_bic sm_bank_bic, pb.acc_number sm_acc_number FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id /*WHERE sm.state = 'valid'*/) sm ON pb_partner_id = p.id
	LEFT OUTER JOIN (SELECT MAX(date_invoice) aanmaak_factuur, partner_id, amount_total/*, invoice_id*/ FROM donation_donation_line GROUP BY partner_id, /*invoice_id,*/ amount_total) ddl 
		ON dpa.partner_id = ddl.partner_id AND dpa.donation_amount = ddl.amount_total
	--JOIN account_invoice i ON ddl.invoice_id = i.id
--WHERE (dpa.next_invoice_date = '2017-03-01' OR dpa.donation_start = '2017-03-01') AND interval_type = 'M'
WHERE interval_type = 'J' AND COALESCE(dpa.donation_cancel,'2099-12-31') = '2099-12-31' AND p.active AND COALESCE(dpa.next_invoice_date,'2021-01-01')>'2021-01-01'
	--AND dpa.donation_amount < 0
--WHERE interval_type = 'M' AND COALESCE(dpa.donation_cancel,'2099-12-31') >= now()::date AND dpa.next_invoice_date > '2019-01-01' --AND p.active = 'false'
--ORDER BY dpa.next_invoice_date
ORDER BY ddl.aanmaak_factuur



--SELECT * FROM donation_partner_account dpa WHERE dpa.partner_id = 334230



--SELECT * FROM donation_partner_account LIMIT 10
----------------------------------------
-- SEPA-Giften
-- volgende facturatie datum
----------------------------
/*
SELECT DISTINCT dpa.next_invoice_date
FROM res_partner p
	JOIN donation_partner_account dpa ON p.id = dpa.partner_id
	JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state, pb.bank_bic sm_bank_bic, pb.acc_number sm_acc_number FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id) sm ON pb_partner_id = p.id
	LEFT OUTER JOIN (SELECT MAX(date_invoice) aanmaak_factuur, partner_id, amount_total, invoice_id FROM donation_donation_line GROUP BY partner_id, invoice_id, amount_total) ddl 
		ON dpa.partner_id = ddl.partner_id AND dpa.donation_amount = ddl.amount_total
WHERE interval_type = 'J'
*/
-----------------------------------------
-- SEPA-Giften
-- giften per specifieke volgende facturatie datum
--------------------------------------------------
/*
SELECT DISTINCT dpa.partner_id id, p.name, dpa.interval_type, dpa.interval_number, dpa.donation_amount bedrag, ddl.invoice_id, dpa.next_invoice_date, dpa.last_invoice_date, dpa.donation_cancel,
	ddl.aanmaak_factuur, ddl.amount_total
FROM res_partner p
	JOIN donation_partner_account dpa ON p.id = dpa.partner_id
	JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state, pb.bank_bic sm_bank_bic, pb.acc_number sm_acc_number FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id) sm ON pb_partner_id = p.id
	LEFT OUTER JOIN (SELECT MAX(date_invoice) aanmaak_factuur, partner_id, amount_total, invoice_id FROM donation_donation_line GROUP BY partner_id, invoice_id, amount_total) ddl 
		ON dpa.partner_id = ddl.partner_id AND dpa.donation_amount = ddl.amount_total
WHERE dpa.next_invoice_date = '2017-12-15' OR dpa.donation_start = '2017-12-15'
*/
------------------------------------------
/*
SELECT *
FROM donation_donation_line ddl
ORDER BY ddl.date_invoice DESC
LIMIT 100

SELECT *
FROM account_invoice i
WHERE i.id = 601642


SELECT *
FROM donation_partner_account dpa
LIMIT 100


SELECT *
FROM sdd_mandate
LIMIT 100

SELECT *
FROM account_invoice
LIMIT 100

(SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state, pb.bank_bic sm_bank_bic, pb.acc_number sm_acc_number FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id ) sm ON pb_partner_id = p.id
*/