--SET VARIABLES
DROP TABLE IF EXISTS _av_myvar;
CREATE TEMP TABLE _av_myvar (startdatum date, einddatum date, startdatum_groepering date);
INSERT INTO _av_myvar (SELECT '2023-07-01' AS startdatum,
							'2023-07-31' AS einddatum,
					   		now()::date - INTERVAL '25 month' AS startdatum_groepering);
SELECT * FROM _av_myvar;
--=========================================================--
--CREATE TEMP TABLE
-- lijst ID's donateurs met gift tijdens bepaalde periode (startdatum tem einddatum)
DROP TABLE IF EXISTS tempGIFTEN;
CREATE TEMP TABLE tempGIFTEN (
	partner_id numeric);
--
-- lijst donateurs/giften (met projecten) over langere periode obv ID's tabel tempGIFTEN
DROP TABLE IF EXISTS tempGIFTENperproject;
CREATE TEMP TABLE tempGIFTENperproject (
	partner_id numeric,
	bedrag numeric,
	project_code text,
	project text,
	date date);
----------------------
--------------------------------------------------
-- selectie ID's: donateurs van giften over bepaalde periode (startdatum tem einddatum)
-- SELECT * FROM tempGIFTEN
INSERT INTO tempGIFTEN (partner_id)
	(SELECT 
		p.id partner_id
	FROM _av_myvar v, account_move am
		INNER JOIN account_move_line aml ON aml.move_id = am.id
		INNER JOIN account_account aa ON aa.id = aml.account_id
		LEFT OUTER JOIN res_partner p ON p.id = aml.partner_id
		LEFT OUTER JOIN account_analytic_account aaa1 ON aml.analytic_dimension_1_id = aaa1.id
		LEFT OUTER JOIN account_analytic_account aaa2 ON aml.analytic_dimension_2_id = aaa2.id
		LEFT OUTER JOIN account_analytic_account aaa3 ON aml.analytic_dimension_3_id = aaa3.id
	WHERE (aa.code = '732100' OR  aa.code = '732000')
		AND aml.date BETWEEN v.startdatum AND v.einddatum
		AND (p.active = 't' OR (p.active = 'f' AND COALESCE(p.deceased,'f') = 't'))
	 );
----------
----------
-- voor selectie donateurs uit tempGIFTEN worden alle giften + projecten opgehaald over periode van 2,5 jaren
----------
-- QUERY 1: ERP
INSERT INTO tempGIFTENperproject
	(SELECT 
		p.id partner_id,
	 	(aml.credit - aml.debit) bedrag,
		COALESCE(COALESCE(aaa3.code,aaa2.code),aaa1.code) AS project_code,
	 	COALESCE(COALESCE(aaa3.name,aaa2.name),aaa1.name) AS project,
	 	aml.date
	FROM _av_myvar v, account_move am
		INNER JOIN account_move_line aml ON aml.move_id = am.id
		INNER JOIN account_account aa ON aa.id = aml.account_id
		LEFT OUTER JOIN res_partner p ON p.id = aml.partner_id
		LEFT OUTER JOIN account_analytic_account aaa1 ON aml.analytic_dimension_1_id = aaa1.id
		LEFT OUTER JOIN account_analytic_account aaa2 ON aml.analytic_dimension_2_id = aaa2.id
		LEFT OUTER JOIN account_analytic_account aaa3 ON aml.analytic_dimension_3_id = aaa3.id
	WHERE p.id IN (SELECT partner_id FROM tempGIFTEN)
	 	AND (aa.code = '732100' OR  aa.code = '732000')
		AND aml.date BETWEEN v.startdatum_groepering AND v.einddatum
		AND (p.active = 't' OR (p.active = 'f' AND COALESCE(p.deceased,'f') = 't'))	--van de inactieven enkele de overleden contacten meenemen
		--AND p.id = v.testID
	ORDER BY aml.date);
----------
-- QUERY 2: "npca betalingen"
INSERT INTO tempGIFTENperproject
	(SELECT 
		p.id partner_id,
	 	pph.amount bedrag,
		CASE WHEN pph.cost_center = '' THEN pph.project_nbr ELSE COALESCE(pph.cost_center,pph.project_nbr) END AS project_code,
	 	NULL AS project,
	 	pph.date
	FROM _av_myvar v, res_partner p
		JOIN res_partner_payment_history pph ON pph.partner_id = p.id
	WHERE p.id IN (SELECT partner_id FROM tempGIFTEN)
	 	AND pph.project_nbr > '0' 
		AND pph.date BETWEEN v.startdatum_groepering AND v.einddatum
	ORDER BY pph.date); 
----------
-- selectie giften per partner_id/project met selectie op +1 gift per project
SELECT SQ2.*,
	p.first_name as voornaam,
		p.last_name as achternaam,
		CASE WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name ELSE p.street END straat,
		CASE WHEN c.id = 21 AND p.crab_used = 'true' THEN p.street_nbr ELSE '' END huisnummer, 
		p.street_bus bus,
		CASE WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip ELSE p.zip END postcode,
		CASE WHEN c.id = 21 THEN cc.name ELSE p.city END gemeente,
		p.postbus_nbr postbus,
		c.name land,
		p.email, p.email_work,
		CASE WHEN COALESCE(p.opt_out,'f') = 'f' THEN 'JA' WHEN p.opt_out = 't' THEN 'NEEN' ELSE 'JA' END email_ontvangen,
		CASE WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 'JA' WHEN p.opt_out_letter = 't' THEN 'NEEN' ELSE 'JA' END post_ontvangen,
		p.iets_te_verbergen,
		COALESCE(p.deceased,'f') overleden
FROM res_partner p
	JOIN
	(SELECT partner_id, SUM(bedrag) bedrag, project_code, project, EXTRACT('year' FROM AGE(MAX(date),MIN(date))) periode_j, MAX(r) r
	FROM (
			SELECT partner_id, bedrag, project_code, project, date,
				ROW_NUMBER() OVER (PARTITION BY partner_id, project_code ORDER BY partner_id DESC) AS r 
			FROM tempGIFTENperproject
			--WHERE partner_id = 162441
		) SQ1 
	GROUP BY partner_id, project_code, project) SQ2
	ON SQ2.partner_id = p.id
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
WHERE SQ2.periode_j >= 1
ORDER BY r DESC;	