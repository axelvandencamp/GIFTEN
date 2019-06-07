--------------------------------------------------------------
--bevat:
-- - bepalen variabelen
-- - ophalen data
-- - berekening statistieken
-- - berekening fiscale attesten
-- - andere losse hulp queries
--------------------------------------
--Opmerking: aparte query voor domicilieringen (foutieve linking naar facturen) werd niet meer overgenomen uit v2
--------------------------------------------------------------
--SET VARIABLES
DROP TABLE IF EXISTS myvar;
SELECT 
	'2017-01-01'::date AS startdatum,
	'2017-12-31'::date AS einddatum,
	'2012-01-01'::date AS startdatumbosvooriedereen,
	'2013-01-01'::date AS startdatumalledonateurs,
	'16980'::numeric AS testID
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
/*-----------------------------------------------------------
--=========================================================--
-------------------------------------------------------------
--      Aanmaak temptabel om alle giften te verzamelen     --
-------------------------------------------------------------
-----------------------------------------------------------*/
--CREATE TEMP TABLE
DROP TABLE IF EXISTS tempGIFTEN;

CREATE TEMP TABLE tempGIFTEN (
	acount_id numeric,
	date date,
	jaar numeric,
	maand numeric,
	debet numeric,
	credit numeric,
	amount numeric,
	partner_id numeric,
	huidige_lidmaatschap_status text,
	lidnummer text,
	partner text,
	naam text,
	voornaam text,
	achternaam text,
	afdeling text,
	opzegdatum date,
	straat text, 
	huisnummer text, 
	bus text, 
	postcode text, 
	gemeente text, 
	postbus text,
	provincie text,
	land text,
	geboorte_datum date,
	naam_partner text,
	adres_status text,
	email_ontvangen text,
	post_ontvangen text,
	overleden text,
	email text,
	aanspreking text,
	geslacht text,
	description text,
	ref text,
	dimensie1 text,
	dimensie2 text,
	dimensie3 text,
	project_code text,
	project text,
	grootboekrek text,
	grootboekrek_naam text,
	vzw text,
	boeking text,
	bron text);
--/*
--------------------------------------------------
--QUERY 1: ophalen ERP Giften uit "CRM betalingen"
----------
INSERT INTO tempGIFTEN
	(SELECT aml.account_id,
		aml.date,
		EXTRACT(year FROM aml.date) jaar,
		EXTRACT(month FROM aml.date) maand,
		aml.debit, 
		aml.credit,
		(credit - debit) amount,
		p.id p_id,
		p.membership_state huidige_lidmaatschap_status,
		p.membership_nbr lidnummer,
		'[' || p.id::text || '] ' || p.name as partner,
		p.name as naam,
		p.first_name as voornaam,
		p.last_name as achternaam,
		COALESCE(COALESCE(a2.name,a.name),'onbekend') afdeling,
		p.membership_cancel as opzegdatum,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name
			ELSE p.street 
		END straat,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN p.street_nbr ELSE ''
		END huisnummer, 
		p.street_bus bus,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
			ELSE p.zip
		END postcode,
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END gemeente,
		p.postbus_nbr postbus,
		CASE
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 1000 AND 1299 THEN 'Brussel' 
			WHEN p.country_id = 21 AND (substring(p.zip from '[0-9]+')::numeric BETWEEN 1500 AND 1999 OR substring(p.zip from '[0-9]+')::numeric BETWEEN 3000 AND 3499) THEN 'Vlaams Brabant'
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 2000 AND 2999  THEN 'Antwerpen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 3500 AND 3999  THEN 'Limburg' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 8000 AND 8999  THEN 'West-Vlaanderen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 9000 AND 9999  THEN 'Oost-Vlaanderen' 
			WHEN p.country_id = 21 THEN 'Wallonië'
			WHEN p.country_id = 166 THEN 'Nederland'
			WHEN NOT(p.country_id IN (21,166)) THEN 'Buitenland niet NL'
			ELSE 'andere'
		END AS provincie,
		c.name land,
		p.birthday,
		a5.name partner_naam,
		COALESCE(p.address_state_id,0) adres_status,
		CASE WHEN COALESCE(p.opt_out,'f') = 'f' THEN 'JA' WHEN p.opt_out = 't' THEN 'NEEN' ELSE 'JA' END email_ontvangen,
		CASE WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 'JA' WHEN p.opt_out_letter = 't' THEN 'NEEN' ELSE 'JA' END post_ontvangen,
		COALESCE(p.deceased,'f') overleden,
		p.email,
		CASE
			WHEN p.gender = 'M' THEN 'Dhr.'
			WHEN p.gender = 'V' THEN 'Mevr.'
			ELSE pt.shortcut
		END aanspreking,
		p.gender AS geslacht,
		REPLACE(REPLACE(REPLACE(aml.name,';',','),chr(10),' '),chr(13), ' ') as description,
		aml.ref,
		--aaa.code,
		COALESCE(aaa1.name,'') dimensie1,
		COALESCE(aaa2.name,'') dimensie2,
		COALESCE(aaa3.name,'') dimensie3,
		COALESCE(COALESCE(aaa3.code,aaa2.code),aaa1.code) AS project_code,
		COALESCE(COALESCE(aaa3.name,aaa2.name),aaa1.name) AS project,
		aa.code grootboekrek,
		REPLACE(aa.name,';',',') grootboekrek_naam,
		rc.name AS vzw,
		am.name AS boeking,
		'ERP' AS bron
	FROM myvar v, account_move am
		INNER JOIN account_move_line aml ON aml.move_id = am.id
		INNER JOIN account_account aa ON aa.id = aml.account_id
		LEFT OUTER JOIN res_partner p ON p.id = aml.partner_id
		LEFT OUTER JOIN account_analytic_account aaa1 ON aml.analytic_dimension_1_id = aaa1.id
		LEFT OUTER JOIN account_analytic_account aaa2 ON aml.analytic_dimension_2_id = aaa2.id
		LEFT OUTER JOIN account_analytic_account aaa3 ON aml.analytic_dimension_3_id = aaa3.id

		JOIN res_company rc ON aml.company_id = rc.id 
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--link naar partner		
		LEFT OUTER JOIN res_partner a5 ON p.relation_partner_id = a5.id
	WHERE (aa.code = '732100' OR  aa.code = '732000')
		AND aml.date BETWEEN v.startdatum AND v.einddatum
		AND (p.active = 't' OR (p.active = 'f' AND COALESCE(p.deceased,'f') = 't'))	--van de inactieven enkele de overleden contacten meenemen
		--AND p.id = v.testID
	ORDER BY aml.date);
--*/

--/*
--------------------------------------------------
--QUERY 2: ophalen NPCA Giften uit ERP: "npca betalingen"
----------
INSERT INTO tempGIFTEN
	(SELECT 
		null AS account_id,
		pph.date,
		EXTRACT(year FROM pph.date) jaar,
		EXTRACT(month FROM pph.date) maand,
		NULL debet,
		NULL credit,
		pph.amount,
		p.id p_id,
		p.membership_state_b huidige_lidmaatschap_status,
		p.membership_nbr lidnummer,
		'[' || p.id::text || '] ' || p.name as partner,
		p.name as naam,
		p.first_name as voornaam,
		p.last_name as achternaam,
		COALESCE(COALESCE(a2.name,a.name),'onbekend') afdeling,
		p.membership_cancel_b as opzegdatum,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name
			ELSE p.street
		END straat,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN p.street_nbr ELSE ''
		END huisnummer, 
		p.street_bus bus,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
			ELSE p.zip
		END postcode,
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END gemeente,
		p.postbus_nbr postbus,
		CASE
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 1000 AND 1299 THEN 'Brussel' 
			WHEN p.country_id = 21 AND (substring(p.zip from '[0-9]+')::numeric BETWEEN 1500 AND 1999 OR substring(p.zip from '[0-9]+')::numeric BETWEEN 3000 AND 3499) THEN 'Vlaams Brabant'
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 2000 AND 2999  THEN 'Antwerpen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 3500 AND 3999  THEN 'Limburg' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 8000 AND 8999  THEN 'West-Vlaanderen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 9000 AND 9999  THEN 'Oost-Vlaanderen' 
			WHEN p.country_id = 21 THEN 'Wallonië'
			WHEN p.country_id = 166 THEN 'Nederland'
			WHEN NOT(p.country_id IN (21,166)) THEN 'Buitenland niet NL'
			ELSE 'andere'
		END AS provincie,
		c.name land,
		p.birthday,
		a5.name,
		COALESCE(p.address_state_id,0) adres_status,
		CASE WHEN COALESCE(p.opt_out,'f') = 'f' THEN 'JA' WHEN p.opt_out = 't' THEN 'NEEN' ELSE 'JA' END email_ontvangen,
		CASE WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 'JA' WHEN p.opt_out_letter = 't' THEN 'NEEN' ELSE 'JA' END post_ontvangen,
		COALESCE(p.deceased,'f') overleden,
		p.email,
		CASE
			WHEN p.gender = 'M' THEN 'Dhr.'
			WHEN p.gender = 'V' THEN 'Mevr.'
			ELSE pt.shortcut
		END aanspreking,
		p.gender AS geslacht,
		REPLACE(REPLACE(REPLACE(pph.description,';',','),chr(10),' '),chr(13), ' ') AS description,
		NULL AS ref,
		--pph.project_nbr,
		pph.project_nbr dimensie1,
		pph.cost_center dimensie2,
		NULL AS dimensie3,
		--COALESCE(pph.cost_center,pph.project_nbr) AS project_code,
		CASE WHEN pph.cost_center = '' THEN pph.project_nbr ELSE COALESCE(pph.cost_center,pph.project_nbr) END AS project_code,
		NULL AS project,
		NULL AS grootboekrek,
		NULL AS grootboekrek_naam,
		NULL AS vzw,
		NULL AS boeking,
		'npca' AS bron
	FROM myvar v, res_partner p
		JOIN res_partner_payment_history pph ON pph.partner_id = p.id
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--link naar partner		
		LEFT OUTER JOIN res_partner a5 ON p.relation_partner_id = a5.id
	WHERE pph.project_nbr > '0' 
		AND pph.date BETWEEN v.startdatum AND v.einddatum
		--AND pph.date < v.einddatum
		AND p.active = 't' -- niet actieven ook meenemen; kunnen mogelijk wel giften hebben gedaan
		--AND p.deceased = 'f' -- overledenen niet
		--AND COALESCE(p.membership_state_b,'--') IN ('wait_member','invoiced','none','paid','--','')
		--AND aaa.code IN ('F-03333','F-03333A','F-03333B','F-03333C','F-03333D') --bos voor iedereen
		--AND p.address_state_id IN (1,3,4) --"adres verkeerd" niet
		--AND p.opt_out = 'f' --email uitschrijven niet
		--AND p.opt_out_letter = 'f' --brieven uitschrijven niet
		--AND p.id = v.testID
	ORDER BY pph.date); 
