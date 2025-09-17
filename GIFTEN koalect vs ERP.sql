
--=================================================================
--SET VARIABLES
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(startdatum DATE, einddatum DATE
	 );
INSERT INTO _AV_myvar VALUES('2025-01-01',	--startdatum
				'2026-12-31'	--einddatum
				);
SELECT * FROM _AV_myvar;
--====================================================================

SELECT k.project k_project, k.transactie_id k_transactie_id, k.amount k_amount, k.benefiting k_benefiting, k.benefiting_reference k_benefiting_reference, 
	g.*
FROM _AV_myvar v, marketing._m_dwh_koalectV2 k
	LEFT OUTER JOIN marketing._m_sproc_rpt_giften('CST',v.startdatum,v.einddatum,0,15) g ON k.transactie_id::text = REPLACE(regexp_replace(substring(g.description,0,strpos(g.description,'?')), '\D','','g'),'00000','')
WHERE k.project = '24 uur voor natuur - Mandelstampers '

-- -
/*
FROM marketing._m_sproc_rpt_giften(prm_periode,v_startdatum,v_einddatum,0,15) g

REPLACE(regexp_replace(substring(g.description,0,strpos(g.description,'?')), '\D','','g'),'00000','') erp_trans,

SELECT * FROM marketing._m_dwh_koalectV2 WHERE project = '24 uur voor natuur - Mandelstampers '
SELECT * FROM marketing._m_dwh_koalectV2 WHERE transactie_id IN (704418,702284)
*/

