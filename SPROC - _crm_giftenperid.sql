-- Function: public._crm_giftenperid(integer)

-- DROP FUNCTION public._crm_giftenperid(integer);

CREATE OR REPLACE FUNCTION public._crm_giftenperid(
    IN partner_id_in integer,
    OUT jaareerstegift double precision,
    OUT jaarlaatstegift double precision,
    OUT jarendonateur double precision,
    OUT aantalgiften bigint,
    OUT totaalgiften double precision,
    OUT grootstegift double precision,
    OUT avggiftenperjaar double precision,
    OUT avgbedragperjaar double precision)
  RETURNS SETOF record AS
$BODY$
BEGIN
	RETURN QUERY 
	SELECT MIN(SQ1.jaar) jaareerstegift,
		MAX(SQ1.jaar) jaarlaatstegift,
		MAX(SQ1.jaar) - MIN(SQ1.jaar) +1 jarendonateur,
		COUNT(SQ1.p_id) aantalgiften,
		SUM(SQ1.amount) totaalgiften,
		--MIN(SQ1.amount) kleinstegift,
		MAX(SQ1.amount) grootstegift,
		CASE WHEN MAX(SQ1.jaar) = MIN(SQ1.jaar)
			THEN COUNT(SQ1.p_id) --/ 1
			ELSE COUNT(SQ1.p_id) / (MAX(SQ1.jaar) - MIN(SQ1.jaar)) 
		END avggiftenperjaar,
		CASE WHEN MAX(SQ1.jaar) = MIN(SQ1.jaar)  
			THEN SUM(SQ1.amount) --/ 1
			ELSE SUM(SQ1.amount) / (MAX(SQ1.jaar) - MIN(SQ1.jaar)) 
		END avgbedragperjaar
	-- SELECT *
	FROM (
		SELECT aml.account_id,
			aml.date,
			EXTRACT(year FROM aml.date)::numeric jaar,
			EXTRACT(month FROM aml.date)::numeric maand,
			EXTRACT(week FROM aml.date)::numeric week,
			aml.debit, 
			aml.credit,
			(aml.credit - aml.debit) amount,
			p.id p_id
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
			--AND p.id = 229710 --testwaarde
		UNION ALL
		SELECT 
			null AS account_id,
			pph.date,
			EXTRACT(year FROM pph.date) jaar,
			EXTRACT(month FROM pph.date) maand,
			EXTRACT(week FROM pph.date) week,
			NULL debet,
			NULL credit,
			pph.amount,
			p.id p_id
		FROM res_partner p
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
			--AND p.id = 229710 --testwaarde
		) SQ1
	WHERE SQ1.p_id = partner_id_in --229710 --
	GROUP BY SQ1.p_id
		;

	 
END; 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public._crm_giftenperid(integer)
  OWNER TO axelvandencamp;
GRANT EXECUTE ON FUNCTION public._crm_giftenperid(integer) TO public;
GRANT EXECUTE ON FUNCTION public._crm_giftenperid(integer) TO axelvandencamp;
