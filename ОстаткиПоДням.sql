DECLARE @StartDateC DATETIME = DATETIME2FROMPARTS(2020,06,30,00,00,00,00,00)	/* @StartDate - 1 */
DECLARE @StartDate	DATETIME = DATETIME2FROMPARTS(2020,07,01,00,00,00,00,00)	/*(2020,07,01)*/
DECLARE @EndTime	DATETIME = DATETIME2FROMPARTS(2020,07,31,00,00,00,00,00)	/*(2020,07,31)*/

/***********************************************************************************************************************************************************************************************/
DROP TABLE #tt1, #tt2, #tCalen, #tDay, #TList, #tRes
/****************************************************************************Начальное количество************************************************************************************************/
SELECT
	T1.Period,
	T3._Fld3394 as Art,
	T4._Description as Whouse,
	CAST(SUM(T1.Fld16878Balance_) AS INT) as StQnty
INTO #tt1
FROM (SELECT
	DATEFROMPARTS(DATEPART ( yy , T2._Period ) - 2000, DATEPART ( mm , T2._Period ), DATEPART ( dd , T2._Period  )) AS Period,
	T2._Fld16873RRef AS Fld16873RRef,
	T2._Fld16875RRef AS Fld16875RRef,
	CAST(SUM(T2._Fld16878) AS NUMERIC(32, 8)) AS Fld16878Balance_
FROM 
	dbo._AccumRgT16881 T2
WHERE 
	(T2._Fld725 = 0.0)
	AND DATEFROMPARTS(DATEPART ( yy , T2._Period ) - 2000, DATEPART ( mm , T2._Period ), DATEPART ( dd , T2._Period  )) = @StartDate
	AND (T2._Fld16878 <> 0.0) 
	AND (T2._Fld16878 <> 0.0)
GROUP BY T2._Fld16873RRef,
T2._Fld16875RRef,
T2._Period
HAVING (CAST(SUM(T2._Fld16878) AS NUMERIC(32, 8))) <> 0.0) T1
LEFT OUTER JOIN dbo._Reference142 T3
ON (T1.Fld16873RRef = T3._IDRRef) AND (T3._Fld725 = 0.0)
LEFT OUTER JOIN dbo._Reference223 T4
ON (T1.Fld16875RRef = T4._IDRRef) AND (T4._Fld725 = 0.0)
GROUP BY 
	T1.Period,
	T3._Fld3394,
	T4._Description

/***********************************************************************Движение по складам****************************************************************************************************/

SELECT
	DATEFROMPARTS(DATEPART ( yy , T1._Period ) - 2000,DATEPART ( mm , T1._Period ), DATEPART ( dd , T1._Period  )) as Period,
	T2._Fld3394 as Art,
	T3._Description as Whouse,
	T1._RecordKind,
	CASE	
		WHEN T1._RecordKind = 1
			THEN CAST(SUM(T1._Fld16878) AS INT) * (-1)
		ELSE CAST(SUM(T1._Fld16878) AS INT)
	END as Qnty 
INTO #tt2
FROM dbo._AccumRg16872 T1
LEFT OUTER JOIN dbo._Reference142 T2
ON (T1._Fld16873RRef = T2._IDRRef) AND (T2._Fld725 = 0.0)
LEFT OUTER JOIN dbo._Reference223 T3
ON (T1._Fld16875RRef = T3._IDRRef) AND (T3._Fld725 = 0.0)
WHERE 
	(T1._Fld725 = 0.0)
	AND (DATEFROMPARTS(DATEPART ( yy , T1._Period ) - 2000,DATEPART ( mm , T1._Period ), DATEPART ( dd , T1._Period  )) >= @StartDate
	AND DATEFROMPARTS(DATEPART ( yy , T1._Period ) - 2000,DATEPART ( mm , T1._Period ), DATEPART ( dd , T1._Period  ))  <= @EndTime)
GROUP BY 
	T1._Period,
	T2._Fld3394,
	T3._Description,
	T1._RecordKind
ORDER BY 
	T1._Period
/***********************************************************************Агрегирование внутри дня****************************************************************************************************/	
SELECT 
	#tt2.Period,
	#tt2.Art,
	#tt2.Whouse,
	SUM(#tt2.Qnty) as DayQnty
INTO #tDay
FROM #tt2
GROUP BY 
	#tt2.Period,
	#tt2.Whouse,
	#tt2.Art
ORDER BY 
	#tt2.Period
/****************************************************************Определение списка пар артикул - склад************************************************************************************/
SELECT 
	ISNULL(T1.Art, T2.Art) as Art,
	ISNULL(T1.Whouse, T2.Whouse) as Whouse
INTO #TList
FROM
(SELECT DISTINCT
	#tDay.Art,
	#tDay.Whouse
FROM #tDay) AS T1

FULL JOIN

(SELECT DISTINCT
	#tt1.Art,
	#tt1.Whouse
FROM #tt1) as T2

on T1.Art = T2.Art
	and T1.Whouse = T2.Whouse

/*******************************************************************************Календарь****************************************************************************************************/	
SELECT * 
INTO #tCalen
FROM   (SELECT @StartDateC + RN  AS Period 
        FROM   (SELECT ROW_NUMBER() 
                         OVER ( 
                           ORDER BY (SELECT NULL)) RN 
                FROM   master..[spt_values]) T) T1
		CROSS JOIN #TList
		 
WHERE  T1.Period <= @EndTime

/*******************************************************************************Соединение начального остатка и движения с календарем**********************************************************************/	
SELECT DISTINCT
	T1.Period,
	T1.Art,
	T1.Whouse,
	CASE
		WHEN DAY(T1.Period) = '01'
			THEN ISNULL(T3.StQnty,0)
		ELSE ISNULL(T2.DayQnty,0)
	END as Qnty	
INTO #tRes
FROM
(
SELECT 
	*
FROM #tCalen ) as T1

LEFT JOIN 

(SELECT *
FROM #tDay) as T2

on T1.Period = T2.Period
	and T1.Art = T2.Art
	and T1.Whouse = T2.Whouse

LEFT JOIN 

(SELECT *
FROM #tt1) as T3

on T1.Period = T3.Period
	and T1.Art = T3.Art
	and T1.Whouse = T3.Whouse
/*******************************************************************************Расчет остатка по дням**********************************************************************/
SELECT  DISTINCT
	#tRes.Period,
	#tRes.Art,
	#tRes.Whouse,
	#tRes.Qnty,
    coalesce(sum(#tRes.Qnty) over (partition by #tRes.Art, #tRes.Whouse order by #tRes.Period
                rows between unbounded preceding and current row), 
                0) as totalQnty
FROM #tRes
ORDER BY 
	#tRes.Period,
	#tRes.Art
