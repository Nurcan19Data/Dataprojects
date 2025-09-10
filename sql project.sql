--1. Hər müştərinin sonuncu tranzaksiyasının tarixi və həmin tarixdən bugünədək neçə gün keçdiyinin ekrana çıxardılması

select  d.cardholderid,d.firstname,d.lastname,max(t.transactionenddatetime),
trunc(sysdate-max(t.transactionenddatetime)) as days_since_last_transactiondate
from Texas t
join dim_customers d on t.cardholderid=d.cardholderid
group by d.cardholderid,d.firstname,d.lastname
order by days_since_last_transactiondate desc;




--2. Ən böyük məbləğli tranzaksiyanı edən şəxsin adı və hansı məbləğdə tranzaksiya etdiyi və hansı peşənin sahibi olması
SELECT c.FIRSTNAME,c.LASTNAME,t.TRANSACTIONAMOUNT,c.OCCUPATION
FROM texas t
JOIN dim_customers c ON t.CARDHOLDERID = c.CARDHOLDERID
WHERE t.TRANSACTIONAMOUNT in (SELECT MAX(TRANSACTIONAMOUNT) FROM texas t);




--3. Heç tranzaksiya etməmiş neçə müştərinin sayının təyini
select count(*) as no_transaction_customers
from dim_customers c
where not exists(select 1 from texas t where t.cardholderid=c.cardholderid);





--4. Hər müştəriyə görə tranzaksiya məbləği ortalamasının tapılması və yalnız tam hissə məbləğlərin yuvarlaşdırılaraq kəsr hissəsiz ekrana çıxardılması.
-- Burada müştəri adlarını ekrana çıxararkən bütün adların bütün simvollarının böyük hərflə qeyd edilməsi lazımdır.
select upper(d.firstname),round(avg(t.transactionamount),0) 
from dim_customers d
join texas t on d.cardholderid=t.cardholderid
group by d.firstname




--5. Ən uzun müddətli 10 transaksiyanı tapmaq.
select t.*,(t.transactionenddatetime-t.transactionstartdatetime)*24*60 as long_term
from texas t 
order by long_term desc;






--6. Hər bir Tranzaksiya Tipinə Görə Ümumi Tranzaksiya Sayı və Toplam Məbləğin tapilmasi.
select d.transactiontypename,count(t.transactionid),sum(t.transactionamount)
from texas t
join dim_transaction_type d on d.transactionid=t.transactiontypeid
group by d.transactiontypename;





--7. BirthDate sütununa əsasən müştəriləri yaş qruplarına ayırın və ortalama tranzaksiya məbləğini göstərin.
-- (25 yaşdan aşağı, 25-40 yaş, 41-60 yaş ve 60 yaşdan yuxarı)
SELECT Age_Group,ROUND(AVG(TRANSACTIONAMOUNT),0) AS Average_Transaction_Amount
FROM (SELECT t.transactionamount,
    CASE
      WHEN FLOOR(MONTHS_BETWEEN(SYSDATE, d.BIRTHDATE) / 12) < 25 THEN 'Under 25'
      WHEN FLOOR(MONTHS_BETWEEN(SYSDATE, d.BIRTHDATE) / 12) BETWEEN 25 AND 40 THEN '25-40'
      WHEN FLOOR(MONTHS_BETWEEN(SYSDATE, d.BIRTHDATE) / 12) BETWEEN 41 AND 60 THEN '41-60'
      ELSE 'Above 60'
    END AS Age_Group
  FROM texas t
  JOIN dim_customers d ON d.CARDHOLDERID = t.CARDHOLDERID)
GROUP BY Age_Group
ORDER BY Age_Group;






--8. ATMID-yə görə hər bir ATM-də yerli və qeyri-yerli müştərilərin tranzaksiya sayını göstərin.
SELECT atmid,Customer_type,COUNT(transactionid) AS Transaction_Count
FROM (
  SELECT
    t.transactionid,d.atmid,
    CASE
      WHEN SUBSTR(d.cardholderid, 1, 2) = SUBSTR(d.atmid, 1, 2) THEN 'Local'
      ELSE 'Non-Local'
    END AS Customer_Type
  FROM texas t
  join dim_customers d on d.cardholderid=t.cardholderid)
GROUP BY atmid,Customer_type
ORDER BY atmid,Customer_Type;



--9. Ən Çox Müxtəlif ATM-lərdən İstifadə Edən İlk 10 Müştəri

select d.cardholderid,count(distinct d.atmid ) as unique_atm
from dim_customers d
group by d.cardholderid
order by unique_atm desc
fetch first 10 rows only ;

--10. Müştəri Tiplərinə Görə Ümumi Tranzaksiya Məbləği
SELECT
  sub.Customer_Type,
  SUM(sub.transactionamount) AS Total_Transaction_Amount
FROM (
  SELECT
    t.LOCATIONID,
    t.transactionamount,                        
    CASE
      WHEN SUBSTR(d.atmid, 1, 2) = SUBSTR(t.CARDHOLDERID, 1, 2) THEN 'Local'
      ELSE 'Non-Local'
    END AS Customer_Type
  FROM texas t 
  join dim_customers d on d.cardholderid=t.cardholderid 
) sub
GROUP by sub.Customer_Type
ORDER by sub.Customer_Type;




--11. Müştəri Adlarının Duplicated Olmadığı Üzrə Tranzaksiyalar
SELECT t.*
FROM texas t
JOIN dim_customers c ON t.CARDHOLDERID = c.CARDHOLDERID
WHERE c.firstname IN (
  SELECT firstname
  FROM dim_customers
  GROUP by firstname
  HAVING COUNT(*) = 1
);

--12. Hər Müştəri Üçün Tranzaksiya İlinə Görə Bölünməsi
SELECT t.CARDHOLDERID,
EXTRACT(YEAR FROM t.transactionstartdatetime) AS Transaction_Year,SUM(t.TRANSACTIONAMOUNT) AS Total_Amount
FROM texas t
GROUP BY t.CARDHOLDERID, EXTRACT(YEAR from t.transactionstartdatetime)
ORDER BY t.CARDHOLDERID, Transaction_Year;

----13. Hər Müştərinin Ən Çox Tranzaksiya Etmiş Olduğu ATM
SELECT
  CARDHOLDERID,
  atmid,
  Transaction_Count
FROM (
  SELECT
    t.CARDHOLDERID,
    d.atmid,
    COUNT(*) AS Transaction_Count,
    RANK() OVER (PARTITION BY t.CARDHOLDERID ORDER BY COUNT(*) DESC) AS rnk
  FROM texas t join dim_customers d on d.cardholderid=t.cardholderid
  GROUP BY t.CARDHOLDERID,d.atmid
) sub
WHERE rnk = 1
ORDER BY transaction_count desc;


--14. Müştərilərin həftəlik tranzaksiya sayı və ortalama tranzaksiya məbləğini tapin.
SELECT
  c.FIRSTNAME,
  c.LASTNAME,
  t.CARDHOLDERID,
  TO_CHAR(t.TRANSACTIONSTARTDATETIME, 'w') AS WeekNumber,
  COUNT(*) AS Transaction_Count,
  AVG(t.TRANSACTIONAMOUNT) AS Avg_Transaction_Amount
FROM texas t
JOIN dim_customers c ON t.CARDHOLDERID = c.CARDHOLDERID
GROUP BY c.FIRSTNAME, c.LASTNAME, t.CARDHOLDERID, TO_CHAR(t.TRANSACTIONSTARTDATETIME, 'w')
ORDER BY c.FIRSTNAME, WeekNumber;



--15. Hər Müştərinin Ən Yüksək Tranzaksiya Məbləğinin 2-ci Yüksək Məbləğdən Fərqi (yalnız iki və daha çox tranzaksiya edən müştərilər)
SELECT
  CARDHOLDERID,
  MAX(CASE WHEN rnk = 1 THEN TRANSACTIONAMOUNT END) -
  MAX(CASE WHEN rnk = 2 THEN TRANSACTIONAMOUNT END) AS Amount_Difference
FROM (
  SELECT
    t.CARDHOLDERID,
    t.TRANSACTIONAMOUNT,
    RANK() OVER (PARTITION BY t.CARDHOLDERID ORDER BY t.TRANSACTIONAMOUNT DESC) AS rnk
  FROM texas t
) sub
WHERE rnk <= 2
GROUP BY CARDHOLDERID
HAVING COUNT(*) = 2 
ORDER BY CARDHOLDERID;
