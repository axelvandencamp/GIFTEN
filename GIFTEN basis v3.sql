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
	'2023-01-01'::date AS startdatum,
	'2023-12-31'::date AS einddatum,
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
	nooit_contacteren text,
	overleden text,
	email text,
	aanspreking text,
	geslacht text,
	rechtspersoon text,
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
		p.iets_te_verbergen,
		COALESCE(p.deceased,'f') overleden,
		p.email,
		CASE
			WHEN p.gender = 'M' THEN 'Dhr.'
			WHEN p.gender = 'V' THEN 'Mevr.'
			ELSE pt.shortcut
		END aanspreking,
		p.gender AS geslacht,
	 	pct.name,
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
	 	--link naar rechtspersoon
	 	LEFT OUTER JOIN res_partner_corporation_type pct ON pct.id = p.corporation_type_id
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
		p.iets_te_verbergen,
		COALESCE(p.deceased,'f') overleden,
		p.email,
		CASE
			WHEN p.gender = 'M' THEN 'Dhr.'
			WHEN p.gender = 'V' THEN 'Mevr.'
			ELSE pt.shortcut
		END aanspreking,
		p.gender AS geslacht,
	 	pct.name,
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
	 --link naar rechtspersoon
	 	LEFT OUTER JOIN res_partner_corporation_type pct ON pct.id = p.corporation_type_id
	WHERE pph.project_nbr > '0' 
		AND pph.date BETWEEN v.startdatum AND v.einddatum
		--AND pph.date < v.einddatum
		--AND p.active = 't' -- niet actieven ook meenemen; kunnen mogelijk wel giften hebben gedaan
		--AND p.deceased = 'f' -- overledenen niet
		--AND COALESCE(p.membership_state_b,'--') IN ('wait_member','invoiced','none','paid','--','')
		--AND aaa.code IN ('F-03333','F-03333A','F-03333B','F-03333C','F-03333D') --bos voor iedereen
		--AND p.address_state_id IN (1,3,4) --"adres verkeerd" niet
		--AND p.opt_out = 'f' --email uitschrijven niet
		--AND p.opt_out_letter = 'f' --brieven uitschrijven niet
		--AND p.id = v.testID
	ORDER BY pph.date); 
UPDATE tempGIFTEN SET voornaam = '' WHERE voornaam IS NULL;
UPDATE tempGIFTEN SET achternaam = '' WHERE achternaam IS NULL;
UPDATE tempGIFTEN SET bus = '' WHERE bus IS NULL;	
UPDATE tempGIFTEN SET huisnummer = '' WHERE huisnummer IS NULL;	
UPDATE tempGIFTEN SET email = '' WHERE email IS NULL;	
UPDATE tempGIFTEN SET lidnummer = '' WHERE lidnummer IS NULL;
/*
SELECT *
FROM tempGIFTEN g
	JOIN marketing._m_dwh_waarnemingenbe_nieuwsbrief wn ON wn.partner_id = g.partner_id
	JOIN marketing._m_dwh_donateursprofiel dp ON dp.parnter_id = g.pa
*/
/*----------------------------------------------
-- queries verzendlijsten bedankingsmails giften
------------------------------------------------
-- totaal
SELECT COUNT(partner_id) aantal, SUM(amount) bedrag FROM tempGIFTEN WHERE project_code LIKE '%3941%' -- totaal aantal giften + totaal bedrag
-- via post	
SELECT DISTINCT partner_id, amount bedrag, description, project,  naam, voornaam, achternaam, 
	straat || CASE WHEN LENGTH(COALESCE(huisnummer,'_'))>0 THEN ' '||huisnummer ELSE '' END || CASE WHEN LENGTH(COALESCE(bus,'_'))>0 THEN '/'||bus ELSE '' END  adres,
	straat, huisnummer, bus, postcode, gemeente, provincie, land, email, afdeling, lidnummer, huidige_lidmaatschap_status--, overleden, adres_status, post_ontvangen, email_ontvangen, nooit_contacteren
FROM tempGIFTEN 
WHERE project_code LIKE '%3941%' 
	AND NOT(COALESCE(email,'__') LIKE '%@%') -- geen email adres
	AND overleden = 'false' 
	AND adres_status::numeric <> 2 -- niet 'adres verkeerd'
	AND post_ontvangen = 'JA' 
GROUP BY partner_id,  amount, description, project,  naam, voornaam, achternaam, straat, huisnummer, bus, postcode, gemeente, provincie, land, email, afdeling, lidnummer, huidige_lidmaatschap_status--, overleden, adres_status, post_ontvangen, email_ontvangen, nooit_contacteren
ORDER BY partner_id	
-- via mail
SELECT DISTINCT partner_id, amount bedrag, description, project,  naam, voornaam, achternaam, 
	straat || CASE WHEN LENGTH(COALESCE(huisnummer,'_'))>0 THEN ' '||huisnummer ELSE '' END || CASE WHEN LENGTH(COALESCE(bus,'_'))>0 THEN '/'||bus ELSE '' END  adres,
	straat, huisnummer, bus, postcode, gemeente, provincie, land, email, afdeling, lidnummer, huidige_lidmaatschap_status--, overleden, adres_status, post_ontvangen, email_ontvangen, nooit_contacteren
FROM tempGIFTEN 
WHERE project_code LIKE '%3941%' 
	AND COALESCE(email,'__') LIKE '%@%' -- wel email adres
	AND overleden = 'false' 
	AND email_ontvangen = 'JA' 
GROUP BY partner_id,  amount, description, project,  naam, voornaam, achternaam, straat, huisnummer, bus, postcode, gemeente, provincie, land, email, afdeling, lidnummer, huidige_lidmaatschap_status--, overleden, adres_status, email_ontvangen, post_ontvangen, nooit_contacteren
ORDER BY partner_id	
*/	
	
/*
SELECT * FROM tempGIFTEN
SELECT SUM(amount), project FROM tempGIFTEN GROUP BY project
--SELECT REPLACE(REPLACE(REPLACE(LOWER(description),' ',''),'mangopaysanpdonation',''),'koalect','') "transaction", * FROM tempGIFTEN --WHERE vzw LIKE '%Beheer%'
--WHERE LOWER(description) LIKE '%triodos%' 
--WHERE LOWER(afdeling) LIKE '%zuidrand%'
--WHERE LOWER(REPLACE(description,' ','')) LIKE '%mangopaysanpexp%' -- '%mangopaysanpexp%';  '%mangopaysanpdonation%'; '%mangopaysanpfundraising%'
--	AND NOT(LOWER(description) LIKE '%saf%' OR LOWER(description) LIKE '%sa f%'
--		OR LOWER(description) LIKE '%salim%' OR LOWER(description) LIKE '%sa lim%'
--		OR LOWER(description) LIKE '%saant%' OR LOWER(description) LIKE '%sa ant%'
--		OR LOWER(description) LIKE '%saovl%' OR LOWER(description) LIKE '%sa ovl%'
--		OR LOWER(description) LIKE '%sawvl%' OR LOWER(description) LIKE '%sa wvl%'
--		OR LOWER(description) LIKE '%sabra%' OR LOWER(description) LIKE '%sa bra%')
--WHERE amount = 500
WHERE partner_id = 153725 ORDER BY date
--WHERE date = '2018-08-20' AND amount = 500
--ORDER BY date
--WHERE bron = 'npca'
--WHERE description LIKE ('%54208%')
--WHERE project_code LIKE '%6684%' ORDER BY naam
--WHERE project LIKE 'Natuurpunt Nete%'

--SELECT DISTINCT date date_______ FROM tempGIFTEN
--WHERE  bron = 'ERP-DOMI' ORDER BY date
--WHERE bron = 'npca';
--WHERE date IN ('2015-11-25','2015-07-14','2015-07-17','2015-07-18') AND bron = 'ERP-DOMI' --uitgestelde giften 2014 geïnd in 2015
*/

---------------------------------------------------------------
--statistieken
------------------------
/*
DROP TABLE IF EXISTS tempGIFTENStats;
CREATE TEMP TABLE tempGIFTENStats (categorie text, subcategorie text, maand numeric, aantal numeric, bedrag numeric, gemiddelde numeric);
-----
-- export als "GIFTEN basis stat.txt"
-----
INSERT INTO tempGIFTENStats (SELECT 'Unieke giften', 'Unieke giften', Null, COUNT(partner_id), SUM(credit)-SUM(debet), (SUM(credit)-SUM(debet))/COUNT(partner_id)--SUM(amount), SUM(amount)/COUNT(partner_id) 
				FROM tempGIFTEN);
INSERT INTO tempGIFTENStats (SELECT 'Giften per maand', 
				CASE 
					WHEN EXTRACT(MONTH FROM date) = 1 THEN 'Jan' WHEN EXTRACT(MONTH FROM date) = 2 THEN 'Feb'
					WHEN EXTRACT(MONTH FROM date) = 3 THEN 'Maa' WHEN EXTRACT(MONTH FROM date) = 4 THEN 'Apr' 
					WHEN EXTRACT(MONTH FROM date) = 5 THEN 'Mei' WHEN EXTRACT(MONTH FROM date) = 6 THEN 'Jun' 
					WHEN EXTRACT(MONTH FROM date) = 7 THEN 'Jul' WHEN EXTRACT(MONTH FROM date) = 8 THEN 'Aug' 
					WHEN EXTRACT(MONTH FROM date) = 9 THEN 'Sep' WHEN EXTRACT(MONTH FROM date) = 10 THEN 'Okt' 
					WHEN EXTRACT(MONTH FROM date) = 11 THEN 'Nov' WHEN EXTRACT(MONTH FROM date) = 12 THEN 'Dec'
				END,				
				EXTRACT(MONTH FROM date),
				COUNT(partner_id), SUM(credit)-SUM(debet), (SUM(credit)-SUM(debet))/COUNT(partner_id)--SUM(amount), SUM(amount)/COUNT(partner_id)	
				FROM tempGIFTEN
				GROUP BY EXTRACT(MONTH FROM date)
				ORDER BY EXTRACT(MONTH FROM date) ASC);
INSERT INTO tempGIFTENStats (SELECT 'rekening', grootboekrek_naam, Null, COUNT(partner_id), SUM(credit)-SUM(debet), (SUM(credit)-SUM(debet))/COUNT(partner_id)--SUM(amount), SUM(amount), SUM(amount)/COUNT(partner_id) 
				FROM tempGIFTEN
				GROUP BY grootboekrek, grootboekrek_naam);
INSERT INTO tempGIFTENStats (SELECT 'afdeling', afdeling, Null, COUNT(partner_id), SUM(credit)-SUM(debet), (SUM(credit)-SUM(debet))/COUNT(partner_id)--SUM(amount), SUM(amount), SUM(amount)/COUNT(partner_id) 
				FROM tempGIFTEN
				GROUP BY afdeling);				
INSERT INTO tempGIFTENStats (SELECT 'vzw', vzw, Null, COUNT(partner_id) aantal, SUM(credit)-SUM(debet), (SUM(credit)-SUM(debet))/COUNT(partner_id) gemiddeld_geefbedrag 
				FROM tempGIFTEN
				GROUP BY vzw);
INSERT INTO tempGIFTENStats (SELECT 'gemeente', gemeente, Null, COUNT(partner_id), SUM(credit)-SUM(debet), (SUM(credit)-SUM(debet))/COUNT(partner_id)--SUM(amount), SUM(amount), SUM(amount)/COUNT(partner_id) 
				FROM tempGIFTEN
				GROUP BY gemeente);
INSERT INTO tempGIFTENStats (SELECT 'project', subcategorie, Null, COUNT(partner_id), SUM(amount), SUM(amount)/COUNT(partner_id) 
				FROM (SELECT CASE WHEN LOWER(RTRIM(LTRIM(project))) = 'bos voor iedereen' THEN 'Bos voor iedereen' ELSE project END subcategorie, partner_id, credit-debet amount
				FROM tempGIFTEN) x
				GROUP BY subcategorie);
SELECT * FROM tempGIFTENStats --WHERE categorie = 'project' AND LOWER(subcategorie) LIKE '%bos voo%'-- voor iedereen'				
--*/
--SELECT * FROM tempGIFTEN LIMIT 100

---------------------------------------------------------------
--FISCALE ATTESTEN
------------------------
/*
--bulk
SELECT * FROM tempGIFTEN
--SELECT SUM(amount) FROM tempGIFTEN -- voor totaal bedrag
WHERE 	grootboekrek = '732000'
	 AND NOT(description LIKE 'GIFT/2014/%')
--LIMIT 10


--fiscale attesten
--lijst donateurs (juiste velden)
SELECT *
--SELECT SUM(amount)
FROM
	(SELECT partner_id, geboorte_datum, rechtspersoon aard_vd_schenker,  aanspreking, geslacht, naam, achternaam, voornaam, naam_partner, straat, huisnummer, bus, postcode, gemeente woonplaats, land, SUM(credit) - SUM(debet) amount, NULL nr, adres_status, email_ontvangen, post_ontvangen, overleden, vzw
	FROM tempGIFTEN
	WHERE 	grootboekrek = '732000' --AND LOWER(vzw) LIKE 'natuurpunt be%' --AND NOT(LOWER(naam) LIKE 'natuurpunt%') AND NOT(LOWER(naam) LIKE 'bezoekersce%') 
		--AND partner_id IN ('255772','265510')
	GROUP BY partner_id, geboorte_datum, rechtspersoon, aanspreking, geslacht, naam, achternaam, voornaam, naam_partner, straat, huisnummer, bus, postcode, gemeente, land, adres_status, email_ontvangen, post_ontvangen, overleden, vzw) x
WHERE amount >= 40 
*/

---------------------------------------------------------------
--lijst unieke donateurs
------------------------
/*
SELECT DISTINCT partner_id, sum(amount) bedrag, jaar, min(date) min_date, max(date) max_date, description, project,  aanspreking, geslacht, naam, voornaam, achternaam, straat, huisnummer, bus, postcode, gemeente, provincie, land, email, afdeling, overleden, adres_status, post_ontvangen, email_ontvangen, nooit_contacteren, lidnummer, huidige_lidmaatschap_status
--SELECT *
FROM tempGIFTEN 
--WHERE postcode IN ('3070','3071','3078','1910','3020','1820','1800','1830','1831','1930','1932','1933','3000','3001','3010','3012','3018','3060','3061','3040','3150','3090','3091','3080','1000','1020','1050','1120','1130')
--WHERE provincie in ('Antwerpen','Oost-Vlaanderen')
WHERE project_code LIKE '%6617%' --AND naam LIKE 'Natuurpunt%'
--WHERE LOWER(description) LIKE 'mangopay sa np exp%' OR LOWER(description) LIKE 'mangopay sanp exp%' OR LOWER(description) LIKE '%expeditie%'
--WHERE grootboekrek = '732000'
GROUP BY partner_id,  jaar, description, project,  aanspreking, geslacht, naam, voornaam, achternaam, straat, huisnummer, bus, postcode, gemeente, provincie, land, email, afdeling, overleden, adres_status, lidnummer, huidige_lidmaatschap_status, email_ontvangen, post_ontvangen, nooit_contacteren
ORDER BY partner_id, jaar --WHERE partner_id IN ('94626','19544')
--voor post overleden, post ontvangen en adres status uitfilteren
--SELECT DISTINCT partner_id FROM tempGIFTEN

SELECT /*partner_id,*/ SUM(amount) bedrag, project
FROM tempGIFTEN
WHERE project_code LIKE '%03333%' AND date >= '2022-10-14'
GROUP BY project
GROUP BY partner_id

-- met link naar [marketing].[_av_temp_websitegebruikers]
SELECT DISTINCT g.partner_id, sum(g.amount) bedrag, g.jaar, min(g.date) min_date, max(g.date) max_date, g.aanspreking, g.geslacht, g.naam, g.voornaam, g.achternaam, g.straat, g.huisnummer, g.bus, postcode, g.gemeente, g.provincie, g.land, g.email, 
	CASE WHEN COALESCE(w.partner_id,0) = 0 THEN 'neen' ELSE 'ja' END website_gebruiker,
	CASE WHEN COALESCE(s.emailaddress,'_') = '_' THEN 'neen' ELSE 'ja' END suppressed,
	g.afdeling, g.overleden, g.adres_status, g.post_ontvangen, g.email_ontvangen, g.nooit_contacteren, g.lidnummer, g.huidige_lidmaatschap_status
FROM tempGIFTEN g
	LEFT OUTER JOIN marketing._av_temp_websitegebruikers w ON w.partner_id = g.partner_id
	LEFT OUTER JOIN marketing._av_temp_suppressionlist s ON LOWER(s.emailaddress) = LOWER(g.email) 
GROUP BY g.partner_id, w.partner_id, g.jaar, g.aanspreking, g.geslacht, g.naam, g.voornaam, g.achternaam, g.straat, g.huisnummer, g.bus, postcode, g.gemeente, g.provincie, g.land, g.email,
	s.emailaddress, g.afdeling, g.overleden, g.adres_status, g.post_ontvangen, g.email_ontvangen, g.nooit_contacteren, g.lidnummer, g.huidige_lidmaatschap_status
ORDER BY g.partner_id, g.jaar
*/
--------------------------------
/*
SELECT * FROM account_move_reconcile WHERE name = 'B-15-185995'	
SELECT * FROM account_move_line WHERE reconcile_id = 266907
SELECT * FROM account_invoice WHERE move_id = 112192	
SELECT * FROM account_invoice_line WHERE invoice_id = 120942
SELECT * FROM membership_membership_line WHERE account_invoice_line = 129463
SELECT * FROM res_partner WHERE id = 19544
SELECT * FROM account_move_line WHERE partner_id = 19544
SELECT * FROM account_move WHERE id = 112192
SELECT * FROM account_analytic_line WHERE move_id IN (362464)
SELECT * FROM account_analytic_line WHERE account_id IN (2901,3833) AND move_id = 112192
SELECT * FROM account_account WHERE id = 3010
*/