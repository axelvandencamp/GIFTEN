-- Function: public._crm_giften(date, date)

-- DROP FUNCTION public._crm_giften(date, date);

CREATE OR REPLACE FUNCTION marketing._crm_giften(
    IN prm_partner_id integer,
	IN startdatum date,
    IN einddatum date,
    OUT account_id integer,
    OUT date date,
    OUT jaar numeric,
    OUT maand numeric,
    OUT week numeric,
    OUT debet numeric,
    OUT credit numeric,
    OUT amount numeric,
    OUT partner_id integer,
    OUT huidige_lidmaatschap_status character varying,
    OUT lidnummer character varying,
    OUT partner text,
    OUT naam character varying,
    OUT voornaam character varying,
    OUT achternaam character varying,
    OUT afdeling character varying,
    OUT afdeling_id integer,
    OUT opzegdatum date,
    OUT straat character varying,
    OUT huisnummer character varying,
    OUT bus text,
    OUT postcode character varying,
    OUT gemeente character varying,
    OUT postbus character varying,
    OUT provincie text,
    OUT land character varying,
    OUT geboorte_datum date,
    OUT naam_partner character varying,
    OUT adres_status integer,
    OUT email_ontvangen text,
    OUT post_ontvangen text,
    OUT overleden boolean,
    OUT email character varying,
    OUT aanspreking character varying,
    OUT geslacht character varying,
    OUT description text,
    OUT ref character varying,
    OUT dimensie1 character varying,
    OUT dimensie2 character varying,
    OUT dimensie3 character varying,
    OUT code1 character varying,
    OUT code2 character varying,
    OUT code3 character varying,
    OUT project_code character varying,
    OUT project character varying,
    OUT grootboekrek character varying,
    OUT fiscaal_attest boolean,
    OUT grootboekrek_naam text,
    OUT boeking character varying,
    OUT boeking_type text,
    OUT rechtspersoon integer,
    OUT particuliere_gift integer,
    OUT vzw character varying)
  RETURNS SETOF record AS
$BODY$
BEGIN
	RETURN QUERY 
	SELECT aml.account_id,
		aml.date,
		EXTRACT(year FROM aml.date)::numeric jaar,
		EXTRACT(month FROM aml.date)::numeric maand,
		EXTRACT(week FROM aml.date)::numeric week,
		aml.debit, 
		aml.credit,
		(aml.credit - aml.debit) amount,
		p.id p_id,
		p.membership_state huidige_lidmaatschap_status,
		p.membership_nbr lidnummer,
		'[' || p.id::text || '] ' || p.name as partner,
		p.name as naam,
		p.first_name as voornaam,
		p.last_name as achternaam,
		COALESCE(COALESCE(a2.name,a.name),'onbekend') afdeling,
		COALESCE(a2.id,a.id) afdeling_id,
		p.membership_cancel as opzegdatum,
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
		COALESCE(aaa1.code,'') code1,
		COALESCE(aaa2.code,'') code2,
		COALESCE(aaa3.code,'') code3,
		COALESCE(COALESCE(aaa3.code,aaa2.code),aaa1.code) AS project_code,
		COALESCE(COALESCE(aaa3.name,aaa2.name),aaa1.name) AS project,
		aa.code grootboekrek,
		CASE
			WHEN aa.code = '732000' THEN true ELSE false
		END fiscaal_attest,
		REPLACE(aa.name,';',',') grootboekrek_naam,
		am.name boeking,
		CASE
			WHEN COALESCE(LOWER(am.name),'') LIKE '%div%' THEN 'correctie' ELSE 'normaal (geen correctie)'
		END boeking_type,
		p.corporation_type_id rechtspersoon,
		CASE
			WHEN COALESCE(p.organisation_type_id,0) > 0 THEN 1 
			WHEN COALESCE(p.corporation_type_id,0) > 0 THEN 1 ELSE 0
		END particuliere_gift,
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
	WHERE (aa.code = '732100' OR  aa.code = '732000')
		AND aml.date BETWEEN startdatum AND einddatum
		AND (CASE 
			 	WHEN COALESCE(prm_partner_id,0) > 0 THEN p.id = prm_partner_id ELSE p.id > 0END)
		--AND (p.active = 't' OR (p.active = 'f' AND COALESCE(p.deceased,'f') = 't'))	--van de inactieven enkele de overleden contacten meenemen
		--AND p.id = v.testID
		;

	 
END; 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION marketing._crm_giften(integer, date, date)
  OWNER TO axelvandencamp;
GRANT EXECUTE ON FUNCTION marketing._crm_giften(integer, date, date) TO public;
GRANT EXECUTE ON FUNCTION marketing._crm_giften(integer, date, date) TO axelvandencamp;
GRANT EXECUTE ON FUNCTION marketing._crm_giften(integer, date, date) TO readonly;


--SELECT * FROM marketing._crm_giften(NULL,'2022-03-06','2022-03-07')



