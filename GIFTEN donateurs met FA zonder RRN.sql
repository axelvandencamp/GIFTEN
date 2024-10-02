DROP TABLE IF EXISTS _temp;
CREATE TEMP TABLE _temp 
	(partner_id integer, bedrag double precision);

INSERT INTO _temp
	SELECT partner_id, sum(bedrag) bedrag
	FROM
	(
	-- donateur met tot geefbedrag (niet intern)
	SELECT p.id partner_id, SUM(g.bedrag) bedrag
	FROM marketing._m_sproc_rpt_giften('YTD',now()::date,now()::date,15) g
		JOIN res_partner p ON p.id = g.partner_id
	WHERE COALESCE(p.organisation_type_id,0) = 0
	GROUP BY p.id
	-- 
	UNION ALL
	-- jaarlijkse sepa gift: geefbedrag
	SELECT p.id partner_id, SUM(dpa.donation_amount) bedrag
	FROM res_partner p
		JOIN donation_partner_account dpa ON p.id = dpa.partner_id
		JOIN (SELECT pb.partner_id FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm
			ON sm.partner_id = p.id
	WHERE p.active
		AND dpa.interval_type = 'J'
		AND COALESCE(dpa.donation_cancel,'2099-12-31') >= now()::date
	GROUP BY p.id
	-- 
	UNION ALL
	-- maandelijkse sepa gift: geefbedrag op jaarbasis
	SELECT p.id  partner_id, SUM(dpa.donation_amount)*12 bedrag
	FROM res_partner p
		JOIN donation_partner_account dpa ON p.id = dpa.partner_id
		JOIN (SELECT pb.partner_id FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm
			ON sm.partner_id = p.id
	WHERE p.active
		AND dpa.interval_type = 'M'
		AND COALESCE(dpa.donation_cancel,'2099-12-31') >= now()::date
	GROUP BY p.id	
	-- 
	UNION ALL
	-- maandelijkse opdracht: geefgedrag + € 40 op jaarbasis
	-- - recente maandelijkse opdrachten vallen nog niet te onderscheiden als maandelijkse opdracht dus hier niet meegenomen
	SELECT partner_id, bedrag
	FROM marketing._m_sproc_rpt_giftenperpartnerperproject('YTD', now()::date, now()::date,16)
	) sq1
	GROUP BY sq1.partner_id;
---	
INSERT INTO _temp
	SELECT partner_id, avgbedragperjaar bedrag
	FROM marketing._m_dwh_donateursprofiel
	WHERE jaarlaatstegift >= 2023 AND jarendonateur >= 2 AND avggiftenperjaar >= 0.75;
---	
SELECT p.id partner_id, SUM(t.bedrag) bedrag,
	COALESCE(p.first_name,'') as voornaam,
	COALESCE(p.last_name,'') as achternaam,
	CASE WHEN c.id = 21 AND p.crab_used = 'true' THEN COALESCE(ccs.name,'') ELSE COALESCE(p.street,'') END straat,
	CASE WHEN c.id = 21 AND p.crab_used = 'true' THEN COALESCE(p.street_nbr,'') ELSE '' END huisnummer, 
	COALESCE(p.street_bus,'') bus,
	CASE WHEN c.id = 21 AND p.crab_used = 'true' THEN COALESCE(cc.zip,'') ELSE COALESCE(p.zip,'') END postcode,
	CASE WHEN c.id = 21 THEN COALESCE(cc.name,'') ELSE COALESCE(p.city,'') END woonplaats,
	_crm_land(c.id) land,
	COALESCE(COALESCE(p.email,p.email_work),'') email,
	COALESCE(p.national_id_nbr,'') RRN, p.tax_certificate
FROM res_partner p
	JOIN _temp t ON t.partner_id = p.id
	--land, straat, gemeente info
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
WHERE t.bedrag >= 40
	AND COALESCE(p.national_id_nbr,'_') = '_'
	AND p.tax_certificate
	AND COALESCE(p.organisation_type_id,0) = 0
GROUP BY p.id,
	p.name, p.first_name, p.last_name, c.id, ccs.name, p.street, p.crab_used, p.street_nbr, p.street_bus, cc.zip, cc.name, p.city, p.email, p.email_work;
---
DROP TABLE IF EXISTS _temp;	
