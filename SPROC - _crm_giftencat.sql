
-- Function: public._crm_giftencat(text)

-- DROP FUNCTION marketing._crm_giftencat(text);

CREATE OR REPLACE FUNCTION marketing._crm_giftencat(
    IN periode text,
    OUT partner_id integer,
    OUT datum date,
    OUT giftcatverwerkt text,
    OUT giftcataantal integer,
    OUT giftcatdonateur text,
    OUT giftcatbedrag integer,
    OUT bedrag numeric,
	OUT description text,
    OUT voornaam character varying,
    OUT achternaam character varying,
    OUT straat character varying,
    OUT huisnummer character varying,
    OUT bus text,
    OUT postcode character varying,
    OUT gemeente character varying,
    OUT land character varying,
    OUT adres_status integer,
    OUT email_ontvangen text,
    OUT post_ontvangen text,
    OUT email character varying,
	OUT telefoonnr character varying,
    OUT dimensie1 character varying,
    OUT dimensie2 character varying,
    OUT dimensie3 character varying,
    OUT code1 character varying,
    OUT code2 character varying,
    OUT code3 character varying,
    OUT project_code character varying,
    OUT project character varying,
    OUT grootboekrek character varying,
    OUT boeking character varying,
    OUT boeking_type text,
    OUT vzw character varying)
  RETURNS SETOF record AS
$BODY$
BEGIN
	RETURN QUERY 
	SELECT p.id,
		aml.date datum,
		CASE
			WHEN aa.code IN ('732100','732000') THEN 'gevalideerd'
			WHEN aa.code = '499010' THEN 'niet verwerkt'
		END giftcatverwerkt,
		CASE 
			WHEN (SELECT aantalgiften FROM _crm_giftenperid(p.id)) = 1 THEN 1
			ELSE 2
		END giftcataantal,
		CASE	--SELECT * FROM res_partner_corporation_type
			WHEN p.organisation_type_id IN (1,3,5,7,8,16) THEN 'Intern'
			WHEN p.corporation_type_id BETWEEN 1 AND 12 THEN 'Vennootschap'
			WHEN p.corporation_type_id = 13 THEN 'Publiekrechterlijk'
			WHEN p.corporation_type_id IN (15,16) THEN 'Stichting'
			WHEN p.corporation_type_id = 17 THEN 'Vereniging'
			ELSE 'Private persoon'
		END giftcatdonateur,
		CASE
			WHEN (aml.credit - aml.debit) < 250 THEN 1
			WHEN (aml.credit - aml.debit) BETWEEN 250 AND 1000 THEN 2
			WHEN (aml.credit - aml.debit) > 1000 THEN 3
		END giftcatbedrag,
		(aml.credit - aml.debit) bedrag,	
		REPLACE(REPLACE(REPLACE(aml.name,';',','),chr(10),' '),chr(13), ' ') as description,
		p.first_name as voornaam,
		p.last_name as achternaam,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name
			ELSE p.street 
		END straat,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN p.street_nbr ELSE ''
		END huisnummer, 
		CASE
			WHEN LENGTH(p.street_bus) > 0 THEN 'bus ' || p.street_bus ELSE ''
		END bus,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
			ELSE p.zip
		END postcode,
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END gemeente,
		c.name land,
		COALESCE(p.address_state_id,0) adres_status,
		CASE WHEN COALESCE(p.opt_out,'f') = 'f' THEN 'JA' WHEN p.opt_out = 't' THEN 'NEEN' ELSE 'JA' END email_ontvangen,
		CASE WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 'JA' WHEN p.opt_out_letter = 't' THEN 'NEEN' ELSE 'JA' END post_ontvangen,
		p.email,
		COALESCE(p.mobile,p.phone) telefoonnr,
		--aaa.code,
		COALESCE(aaa1.name,'') dimensie1,
		COALESCE(aaa2.name,'') dimensie2,
		COALESCE(aaa3.name,'') dimensie3,
		COALESCE(aaa1.code,'') code1,
		COALESCE(aaa2.code,'') code2,
		COALESCE(aaa3.code,'') code3,
		COALESCE(COALESCE(aaa3.code,aaa2.code),aaa1.code) AS project_code,
		COALESCE(COALESCE(aaa3.name,aaa2.name),aaa1.name) AS project,
		aa.code grootboekrek,
		am.name boeking,
		CASE
			WHEN COALESCE(LOWER(am.name),'') LIKE '%div%' THEN 'correctie' ELSE 'normaal (geen correctie)'
		END boeking_type,
		rc.name AS vzw
	FROM account_move am
		INNER JOIN account_move_line aml ON aml.move_id = am.id
		INNER JOIN account_account aa ON aa.id = aml.account_id
		LEFT OUTER JOIN res_partner p ON p.id = aml.partner_id
		LEFT OUTER JOIN account_analytic_account aaa1 ON aml.analytic_dimension_1_id = aaa1.id
		LEFT OUTER JOIN account_analytic_account aaa2 ON aml.analytic_dimension_2_id = aaa2.id
		LEFT OUTER JOIN account_analytic_account aaa3 ON aml.analytic_dimension_3_id = aaa3.id

		JOIN res_company rc ON aml.company_id = rc.id 
		LEFT OUTER JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--link naar partner		
		LEFT OUTER JOIN res_partner a5 ON p.relation_partner_id = a5.id
	WHERE aa.code IN ('732000','732100','499010')
		AND aml.date BETWEEN _crm_startdatum(periode) AND _crm_einddatum(periode)
		--AND (p.active = 't' OR (p.active = 'f' AND COALESCE(p.deceased,'f') = 't'))	--van de inactieven enkele de overleden contacten meenemen
		--AND p.id = v.testID
	UNION
	SELECT p.id,
		bsl.date datum,
		CASE
			WHEN aa.code IN ('732100','732000') THEN 'gecontroleerd'
			WHEN aa.code = '499010' THEN 'niet verwerkt'
		END giftcatverwerkt,
		CASE 
			WHEN (SELECT aantalgiften FROM _crm_giftenperid(p.id)) = 1 THEN 1
			ELSE 2
		END giftcataantal,
		CASE	--SELECT * FROM res_partner_corporation_type
			WHEN p.organisation_type_id IN (1,3,5,7,8,16) THEN 'Intern'
			WHEN p.corporation_type_id BETWEEN 1 AND 12 THEN 'Vennootschap'
			WHEN p.corporation_type_id = 13 THEN 'Publiekrechterlijk'
			WHEN p.corporation_type_id IN (15,16) THEN 'Stichting'
			WHEN p.corporation_type_id = 17 THEN 'Vereniging'
			ELSE 'Private persoon'
		END giftcatdonateur,
		CASE
			WHEN bsl.amount < 250 THEN 1
			WHEN bsl.amount BETWEEN 250 AND 1000 THEN 2
			WHEN bsl.amount > 1000 THEN 3
		END giftcatbedrag,
		bsl.amount bedrag,
		REPLACE(REPLACE(REPLACE(bsl.name,';',','),chr(10),' '),chr(13), ' ') as description,
		p.first_name as voornaam,
		p.last_name as achternaam,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name
			ELSE p.street 
		END straat,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN p.street_nbr ELSE ''
		END huisnummer, 
		CASE
			WHEN LENGTH(p.street_bus) > 0 THEN 'bus ' || p.street_bus ELSE ''
		END bus,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
			ELSE p.zip
		END postcode,
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END gemeente,
		c.name land,
		COALESCE(p.address_state_id,0) adres_status,
		CASE WHEN COALESCE(p.opt_out,'f') = 'f' THEN 'JA' WHEN p.opt_out = 't' THEN 'NEEN' ELSE 'JA' END email_ontvangen,
		CASE WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 'JA' WHEN p.opt_out_letter = 't' THEN 'NEEN' ELSE 'JA' END post_ontvangen,
		p.email,
		COALESCE(p.mobile,p.phone) telefoonnr,
		COALESCE(aaa1.name,'') dimensie1,
		COALESCE(aaa2.name,'') dimensie2,
		COALESCE(aaa3.name,'') dimensie3,
		COALESCE(aaa1.code,'') code1,
		COALESCE(aaa2.code,'') code2,
		COALESCE(aaa3.code,'') code3,
		COALESCE(COALESCE(aaa3.code,aaa2.code),aaa1.code) AS project_code,
		COALESCE(COALESCE(aaa3.name,aaa2.name),aaa1.name) AS project,

		NULL grootboekrek,
		NULL boeking,
		NULL boeking_type,
		NULL AS vzw
		
	FROM account_bank_statement bs
		JOIN account_bank_statement_line bsl ON bs.id = bsl.statement_id
		JOIN account_account aa ON bsl.account_id = aa.id

		LEFT OUTER JOIN res_partner p ON bsl.partner_id = p.id
		LEFT OUTER JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		LEFT OUTER JOIN account_analytic_account aaa1 ON bsl.analytic_dimension_1_id = aaa1.id
		LEFT OUTER JOIN account_analytic_account aaa2 ON bsl.analytic_dimension_2_id = aaa2.id
		LEFT OUTER JOIN account_analytic_account aaa3 ON bsl.analytic_dimension_3_id = aaa3.id
	WHERE bs.name LIKE '%-288-%'
		AND bs.state = 'draft'
		AND aa.code IN ('732000','732100','499010')
		AND NOT(aa.id IN (4211,4209,2415,2691,2537,4210,2098,2145,2365,2690,2162,2217,2722,2173,2571))
		AND bsl.date BETWEEN _crm_startdatum(periode) AND _crm_einddatum(periode)
		;
 
END; 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION marketing._crm_giftencat(text)
  OWNER TO axelvandencamp;

