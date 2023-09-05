--
-- PostgreSQL database dump
--

-- Dumped from database version 15.2
-- Dumped by pg_dump version 15.2

-- Started on 2023-09-05 14:21:43

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 33567)
-- Name: lab; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA lab;


ALTER SCHEMA lab OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 33568)
-- Name: adminpack; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS adminpack WITH SCHEMA pg_catalog;


--
-- TOC entry 3458 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION adminpack; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION adminpack IS 'administrative functions for PostgreSQL';


--
-- TOC entry 859 (class 1247 OID 33579)
-- Name: non_neg_money; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.non_neg_money AS real
	CONSTRAINT non_neg_money_check CHECK ((VALUE >= (0)::double precision));


ALTER DOMAIN public.non_neg_money OWNER TO postgres;

--
-- TOC entry 863 (class 1247 OID 33582)
-- Name: non_negative_bigint; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.non_negative_bigint AS bigint
	CONSTRAINT non_negative_bigint_check CHECK ((VALUE >= 0));


ALTER DOMAIN public.non_negative_bigint OWNER TO postgres;

--
-- TOC entry 867 (class 1247 OID 33585)
-- Name: non_negative_integer; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.non_negative_integer AS integer
	CONSTRAINT non_negative_integer_check CHECK ((VALUE >= 0));


ALTER DOMAIN public.non_negative_integer OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 66191)
-- Name: calculate_late_fee(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_late_fee() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  late_time INT;
  late_fee REAL;
BEGIN
  IF NEW."Factual_DT_Ret" IS NOT NULL AND OLD."Factual_DT_Ret" IS NULL
    AND NEW."Factual_DT_Ret" > (OLD."DT_Car_Transf_To_Cl" + INTERVAL '1 hour' * OLD."rent_time") THEN

    SELECT EXTRACT(EPOCH FROM (NEW."Factual_DT_Ret" - (OLD."DT_Car_Transf_To_Cl" + INTERVAL '1 hour' * OLD."rent_time"))) / 3600
    INTO late_time
    FROM lab."Contract";

    SELECT (late_time * "Price_One_H")
    INTO late_fee
    FROM lab."Price" p
    JOIN lab."Auto" a ON p."Mod_Code" = a."Mod_Code"
    WHERE p."DT_Inter_End" IS NULL
      AND a."Auto_Code" = OLD."Auto_Code";

    UPDATE lab."Contract"
    SET "Late_Fee" = late_fee,
        "Ret_Mark" = true
    WHERE "Contr_Code" = NEW."Contr_Code";
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.calculate_late_fee() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 58012)
-- Name: sp_get_car_count_by_model(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_get_car_count_by_model(IN mod_code integer, OUT carcount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT COUNT(*) INTO carCount
    FROM lab."Auto" a
    JOIN lab."Model" m USING ("Mod_Code")
    WHERE m."Mod_Code" = mod_Code;
END;
$$;


ALTER PROCEDURE public.sp_get_car_count_by_model(IN mod_code integer, OUT carcount integer) OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 58011)
-- Name: sp_getcarcountbymodel(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_getcarcountbymodel(IN mod_code integer, OUT carcount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT COUNT(*) INTO carCount
    FROM lab."Auto" a
    JOIN lab."Model" m USING ("Mod_Code")
    WHERE m."Mod_Code" = mod_Code;
	
END;
$$;


ALTER PROCEDURE public.sp_getcarcountbymodel(IN mod_code integer, OUT carcount integer) OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 58004)
-- Name: sp_getcarcountbymodel(character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_getcarcountbymodel(IN mod_name character varying, OUT carcount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT COUNT(*) INTO carCount
    FROM lab."Auto" a
    JOIN lab."Model" m ON a."Mod_Code" = m."Mod_Code"
    WHERE m."Name" = mod_Name;
END;
$$;


ALTER PROCEDURE public.sp_getcarcountbymodel(IN mod_name character varying, OUT carcount integer) OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 58001)
-- Name: sp_issuecartocl(integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN auto_code integer, IN rent_h integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    discount DECIMAL(10, 2);
    rentPrice INT;
    finalPrice INT;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM lab."Bonus_Card"
        WHERE "Customer_ID" = cl_Code
    ) THEN
        discount := 0.05;
    ELSE
        discount := 0;
    END IF;

    SELECT
        CASE
            WHEN rent_h < 24 THEN "Price_One_H" * rent_h
            ELSE "Price_Long_Inter" * (rent_h / 24)
        END INTO rentPrice
    FROM lab."Price"
    WHERE "Mod_Code" = (SELECT "Mod_Code" FROM lab."Auto" WHERE "Auto_Code" = auto_Code)
        AND "DT_Inter_End" IS NULL;

    finalPrice := CAST(rentPrice * (1 - discount) AS INT);

	INSERT INTO lab."Contract" ("Contr_Code", "Act_Transf_Client", "Act_Transf_Company", "Rent_Price", "DT_Contract", "DT_Car_Transf_To_Cl", "Factual_DT_Ret", "Late_Fee", "Ret_Mark", "Cl_Code", "Stf_Code", "Auto_Code", "rent_time")
	VALUES ((SELECT COALESCE(MAX("Contr_Code"), 0) + 1 FROM lab."Contract"), (SELECT COALESCE(MAX("Act_Transf_Client"), 0) + 1 FROM lab."Contract"), NULL, finalPrice, CURRENT_TIMESTAMP, NULL, NULL, NULL, false, cl_Code, stf_Code, auto_Code, rent_h);

END;
$$;


ALTER PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN auto_code integer, IN rent_h integer) OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 58002)
-- Name: sp_issuecartocl(integer, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN stf_code integer, IN auto_code integer, IN rent_h integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    discount DECIMAL(10, 2);
    rentPrice INT;
    finalPrice INT;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM lab."Bonus_Card"
        WHERE "Cl_Code" = cl_Code
    ) THEN
        discount := 0.05;
    ELSE
        discount := 0;
    END IF;

    SELECT
        CASE
            WHEN rent_h < 24 THEN "Price_One_H" * rent_h
            ELSE "Price_Long_Inter" * (rent_h / 24)
        END INTO rentPrice
    FROM lab."Price"
    WHERE "Mod_Code" = (SELECT "Mod_Code" FROM lab."Auto" WHERE "Auto_Code" = auto_Code)
        AND "DT_Inter_End" IS NULL;

    finalPrice := CAST(rentPrice * (1 - discount) AS INT);

	INSERT INTO lab."Contract" ("Contr_Code", "Act_Transf_Client", "Act_Transf_Company", "Rent_Price", "DT_Contract", "DT_Car_Transf_To_Cl", "Factual_DT_Ret", "Late_Fee", "Ret_Mark", "Cl_Code", "Stf_Code", "Auto_Code", "rent_time")
	VALUES ((SELECT COALESCE(MAX("Contr_Code"), 0) + 1 FROM lab."Contract"), (SELECT COALESCE(MAX("Act_Transf_Client"), 0) + 1 FROM lab."Contract"), NULL, finalPrice, CURRENT_TIMESTAMP, NULL, NULL, NULL, false, cl_Code, stf_Code, auto_Code, rent_h);

END;
$$;


ALTER PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN stf_code integer, IN auto_code integer, IN rent_h integer) OWNER TO postgres;

--
-- TOC entry 230 (class 1255 OID 57999)
-- Name: sp_writeoffcarsbyyear(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_writeoffcarsbyyear(IN targetyear integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    ALTER TABLE lab."Auto"
    ADD COLUMN "Status" BOOLEAN DEFAULT true;
    
    UPDATE lab."Auto"
    SET "Status" = false
    WHERE "Release_Year" < targetYear;
END;
$$;


ALTER PROCEDURE public.sp_writeoffcarsbyyear(IN targetyear integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 216 (class 1259 OID 33587)
-- Name: Accidents; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Accidents" (
    "Accident_DT" timestamp(2) without time zone NOT NULL,
    "Contr_Code" public.non_negative_integer NOT NULL,
    "Place" character varying(100),
    "Damage" character varying(300) NOT NULL,
    "Cl_Is_Guilty" boolean NOT NULL
);


ALTER TABLE lab."Accidents" OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 33590)
-- Name: Auto; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Auto" (
    "Auto_Code" public.non_negative_integer NOT NULL,
    "Mod_Code" public.non_negative_integer NOT NULL,
    "Engine_Num" character varying(30) NOT NULL,
    "Date_Last_TS" timestamp(2) without time zone,
    "Mileage" public.non_negative_integer NOT NULL,
    "Body_Num" character varying(30) NOT NULL,
    "Release_Year" public.non_negative_integer NOT NULL,
    reg_plate character varying(9) NOT NULL,
    "Status" boolean DEFAULT true,
    CONSTRAINT chk_rel_year CHECK ((("Release_Year")::integer > 1980))
);


ALTER TABLE lab."Auto" OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 33594)
-- Name: Bonus_Card; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Bonus_Card" (
    "BC_Code" public.non_negative_bigint NOT NULL,
    "Cl_Code" public.non_negative_integer NOT NULL,
    "Bonus_Sum" public.non_negative_integer NOT NULL,
    CONSTRAINT chk_bonsum CHECK ((length((("Bonus_Sum")::character varying(7))::text) <= 6))
);


ALTER TABLE lab."Bonus_Card" OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 33598)
-- Name: Client; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Client" (
    "Cl_Code" public.non_negative_integer NOT NULL,
    "Email" character varying(256),
    "Address" character varying(100) NOT NULL,
    "Full_Name" character varying(50) NOT NULL,
    "Passport_Data" public.non_negative_bigint NOT NULL,
    "Tel_Num" public.non_negative_bigint NOT NULL,
    CONSTRAINT chk_email CHECK ((("Email")::text ~~ '_%@_%._%'::text)),
    CONSTRAINT chk_passport CHECK (((("Passport_Data")::bigint > 1000000000) AND (("Passport_Data")::bigint <= '9999999999'::bigint))),
    CONSTRAINT chk_phone CHECK (((("Tel_Num")::bigint > '70000000000'::bigint) AND (("Tel_Num")::bigint <= '79999999999'::bigint)))
);


ALTER TABLE lab."Client" OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 33604)
-- Name: Contract; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Contract" (
    "Contr_Code" public.non_negative_integer NOT NULL,
    "Act_Transf_Client" public.non_negative_integer,
    "Act_Transf_Company" public.non_negative_integer,
    "Rent_Price" public.non_neg_money NOT NULL,
    "DT_Contract" timestamp(2) without time zone NOT NULL,
    "DT_Car_Transf_To_Cl" timestamp(2) without time zone,
    "Factual_DT_Ret" timestamp(2) without time zone,
    "Late_Fee" public.non_neg_money,
    "Ret_Mark" boolean NOT NULL,
    "Cl_Code" public.non_negative_integer NOT NULL,
    "Stf_Code" public.non_negative_integer NOT NULL,
    "Auto_Code" public.non_negative_integer NOT NULL,
    rent_time public.non_negative_integer NOT NULL
);


ALTER TABLE lab."Contract" OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 33607)
-- Name: Extension; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Extension" (
    "Extension_Id" public.non_negative_integer NOT NULL,
    "Contr_Code" integer NOT NULL,
    "New_DT_Ret" timestamp without time zone NOT NULL,
    "Ext_Hours" public.non_negative_integer NOT NULL,
    "Sequence_Num" public.non_negative_integer NOT NULL
);


ALTER TABLE lab."Extension" OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 33610)
-- Name: Model; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Model" (
    "Mod_Code" public.non_negative_integer NOT NULL,
    "Name" character varying(40) NOT NULL,
    "Characteristics" character varying(300) NOT NULL,
    "Description" character varying(1500) NOT NULL,
    "Market_Price" public.non_negative_integer,
    "Bail_Sum" public.non_negative_integer NOT NULL
);


ALTER TABLE lab."Model" OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 33615)
-- Name: Penalties; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Penalties" (
    "Penalty_Code" public.non_negative_integer NOT NULL,
    "Accident_DT" timestamp(2) without time zone NOT NULL,
    "Who_Pays" character varying(2) NOT NULL,
    "Payment_Status" boolean NOT NULL,
    "Penalty_Sum" public.non_neg_money NOT NULL,
    CONSTRAINT check_who_pays CHECK ((("Who_Pays")::text = ANY (ARRAY[('Cl'::character varying)::text, ('Co'::character varying)::text, ('Ot'::character varying)::text])))
);


ALTER TABLE lab."Penalties" OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 33619)
-- Name: Price; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Price" (
    "Mod_Code" integer NOT NULL,
    "DT_Inter_Start" timestamp(2) without time zone NOT NULL,
    "DT_Inter_End" timestamp(2) without time zone,
    "Price_One_H" public.non_negative_integer NOT NULL,
    "Price_Long_Inter" public.non_negative_integer NOT NULL,
    "Price_Code" public.non_negative_integer NOT NULL
);


ALTER TABLE lab."Price" OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 33622)
-- Name: Staff; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Staff" (
    "Stf_Code" public.non_negative_integer NOT NULL,
    "Position" character varying(30) NOT NULL,
    "Resps" character varying(200) NOT NULL,
    "Salary" public.non_negative_integer,
    stf_name character varying NOT NULL
);


ALTER TABLE lab."Staff" OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 33627)
-- Name: Violation; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab."Violation" (
    "Violation_Code" public.non_negative_integer NOT NULL,
    "Penalty_Code" integer,
    rtr_viol_code integer NOT NULL
);


ALTER TABLE lab."Violation" OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 33630)
-- Name: insurance_dict; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab.insurance_dict (
    insur_code public.non_negative_integer NOT NULL,
    insur_price public.non_negative_integer NOT NULL,
    insure_name character varying(40) NOT NULL,
    insure_desc character varying(200) NOT NULL,
    "Mod_Code" integer NOT NULL
);


ALTER TABLE lab.insurance_dict OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 33633)
-- Name: rtr_dict; Type: TABLE; Schema: lab; Owner: postgres
--

CREATE TABLE lab.rtr_dict (
    rtr_viol_code public.non_negative_integer NOT NULL,
    viol_fee public.non_neg_money NOT NULL,
    viol_type character varying(100) NOT NULL,
    viol_descript character varying(200) NOT NULL
);


ALTER TABLE lab.rtr_dict OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 58013)
-- Name: carcount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.carcount (
    count bigint
);


ALTER TABLE public.carcount OWNER TO postgres;

--
-- TOC entry 3439 (class 0 OID 33587)
-- Dependencies: 216
-- Data for Name: Accidents; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Accidents" ("Accident_DT", "Contr_Code", "Place", "Damage", "Cl_Is_Guilty") FROM stdin;
2022-07-30 18:04:26	100007	46 Fifth Avenue Lane	A minor damage from a collision with a motorcycle	f
2019-12-05 22:43:06	100006	35 Cedar Lane Street	A severe dents from a collision with a motorcycle	t
2019-07-11 09:39:59	100007	68 First Avenue Road	A cosmetic damage from a collision with a truck	f
2021-01-09 02:15:01	100006	10 Main Street Road	A major scuffs from a collision with a truck	t
2021-02-02 21:56:45	100002	29 Fifth Avenue Road	A minor bumps from a collision with a truck	t
2019-05-18 10:46:53	100018	34 Maple Avenue Road	A severe bumps from a collision with a motorcycle	f
2020-09-03 07:39:11	100004	53 Fourth Street Lane	A severe bumps from a collision with a motorcycle	t
2022-11-11 07:13:46	100008	18 Cedar Lane Avenue	A severe dents from a collision with a car	f
2018-07-05 12:42:25	100013	76 First Avenue Road	A severe bumps from a collision with a bike	t
2020-06-20 18:38:22	100014	97 Fourth Street Road	A minor scratches from a collision with a bike	f
2023-12-03 02:41:32	100013	74 Maple Avenue Road	A minor dents from a collision with a motorcycle	f
2019-07-15 08:04:04	100001	77 Main Street Road	A minor dents from a collision with a truck	f
2021-06-26 10:01:46	100012	1 First Avenue Street	A major dents from a collision with a truck	f
2018-03-02 10:55:19	100010	28 First Avenue Road	A minor damage from a collision with a bike	f
2018-04-16 01:09:58	100003	56 Fifth Avenue Street	A severe scratches from a collision with a car	t
2022-02-07 12:47:30	100001	45 Park Avenue Road	A severe dents from a collision with a truck	f
2023-12-30 23:46:03	100015	38 First Avenue Street	A severe dents from a collision with a motorcycle	f
2023-02-19 10:43:08	100012	65 Main Street Road	A extensive scratches from a collision with a truck	t
2021-04-03 00:31:54	100014	2 Fourth Street Avenue	A major scuffs from a collision with a truck	t
2020-06-03 21:08:00	100019	61 First Avenue Street	A extensive bumps from a collision with a bike	t
2018-04-04 22:42:09	100013	8 Main Street Avenue	A cosmetic bumps from a collision with a truck	t
2019-06-15 00:21:27	100015	53 Elm Street Road	A minor scuffs from a collision with a motorcycle	t
2022-08-03 01:38:50	100020	92 Cedar Lane Street	A cosmetic scuffs from a collision with a bike	t
2019-09-18 13:24:41	100004	45 Second Avenue Street	A extensive damage from a collision with a motorcycle	f
2019-09-07 23:50:08	100019	8 Main Street Avenue	A severe dents from a collision with a bike	f
2021-11-18 17:35:34	100002	48 Main Street Lane	A minor dents from a collision with a bike	t
2019-10-07 10:59:26	100018	68 Second Avenue Avenue	A cosmetic damage from a collision with a truck	t
2020-03-14 14:42:14	100013	93 Main Street Road	A minor scratches from a collision with a truck	t
2021-11-01 06:58:08	100018	5 Maple Avenue Road	A cosmetic scratches from a collision with a motorcycle	f
2019-11-03 16:32:21	100017	36 Fifth Avenue Road	A extensive bumps from a collision with a bike	f
2021-09-15 20:29:29	100003	39 Second Avenue Road	A cosmetic bumps from a collision with a bike	t
2021-07-02 01:45:52	100015	70 Fifth Avenue Avenue	A severe scratches from a collision with a motorcycle	f
2018-12-11 07:47:56	100007	62 Elm Street Lane	A severe dents from a collision with a truck	f
2019-08-14 10:40:44	100008	51 Fifth Avenue Street	A extensive dents from a collision with a motorcycle	t
2023-11-04 02:56:17	100012	52 Third Street Lane	A extensive scuffs from a collision with a car	t
2018-04-07 23:01:37	100010	86 Park Avenue Avenue	A cosmetic scratches from a collision with a truck	f
2019-12-19 19:14:05	100003	2 Park Avenue Road	A major scratches from a collision with a motorcycle	t
2023-01-08 04:46:25	100015	57 Third Street Road	A cosmetic scuffs from a collision with a motorcycle	f
2020-06-01 18:56:42	100005	51 Cedar Lane Avenue	A severe damage from a collision with a bike	t
2022-06-21 16:36:56	100003	29 Third Street Avenue	A minor dents from a collision with a truck	f
2022-10-15 06:44:41	100019	74 First Avenue Avenue	A minor damage from a collision with a motorcycle	t
2023-09-30 09:05:51	100011	31 Cedar Lane Road	A extensive scuffs from a collision with a truck	t
2019-05-12 05:45:24	100015	42 First Avenue Lane	A extensive dents from a collision with a car	f
2020-01-14 04:42:57	100020	43 Third Street Road	A major scuffs from a collision with a motorcycle	t
2023-12-05 10:33:49	100019	65 Second Avenue Lane	A minor bumps from a collision with a truck	f
2023-02-19 11:53:58	100014	78 Main Street Street	A severe bumps from a collision with a car	f
2021-04-11 23:22:26	100017	13 Third Street Lane	A extensive dents from a collision with a motorcycle	f
2018-08-10 00:30:08	100016	97 Fourth Street Avenue	A major scratches from a collision with a car	t
2018-07-01 07:58:23	100016	46 Elm Street Road	A minor scuffs from a collision with a motorcycle	t
2022-11-16 10:01:32	100017	61 Second Avenue Avenue	A severe damage from a collision with a truck	t
2018-02-24 01:27:08	100013	70 Park Avenue Lane	A minor bumps from a collision with a bike	f
2021-09-30 22:29:37	100012	43 First Avenue Avenue	A major bumps from a collision with a car	f
2021-07-12 19:16:31	100012	61 Third Street Street	A major scuffs from a collision with a motorcycle	t
2020-09-23 05:42:30	100004	43 Third Street Street	A cosmetic bumps from a collision with a car	t
2020-11-20 14:38:40	100014	33 Park Avenue Lane	A major dents from a collision with a truck	f
2018-06-22 10:40:30	100002	53 Third Street Road	A major scratches from a collision with a truck	t
2018-05-30 03:47:15	100001	1 Cedar Lane Road	A major damage from a collision with a truck	t
2020-05-29 01:19:14	100007	83 Maple Avenue Street	A severe scratches from a collision with a motorcycle	f
2022-05-06 10:43:21	100014	3 Main Street Lane	A severe scratches from a collision with a car	t
2023-09-10 11:03:07	100004	62 Cedar Lane Lane	A minor damage from a collision with a car	t
2019-10-17 16:58:38	100014	95 Elm Street Street	A major scratches from a collision with a car	t
2020-04-08 13:07:54	100002	16 Fifth Avenue Lane	A major scratches from a collision with a car	t
2021-11-29 02:39:40	100017	44 Fourth Street Road	A severe scratches from a collision with a car	t
2018-01-17 11:40:00	100012	54 Fifth Avenue Street	A severe bumps from a collision with a car	f
2018-04-23 18:47:16	100017	62 Maple Avenue Road	A severe bumps from a collision with a car	t
2020-11-10 12:41:37	100019	97 Cedar Lane Street	A cosmetic bumps from a collision with a truck	f
2022-07-09 06:52:58	100018	11 First Avenue Road	A cosmetic bumps from a collision with a motorcycle	f
2019-05-09 09:46:31	100012	60 Third Street Lane	A severe scuffs from a collision with a truck	f
2023-06-04 11:26:51	100017	10 Elm Street Avenue	A severe scratches from a collision with a car	t
2020-11-04 22:05:37	100016	12 Fifth Avenue Road	A severe scuffs from a collision with a motorcycle	t
2018-06-05 01:00:42	100013	41 Cedar Lane Lane	A severe scratches from a collision with a motorcycle	t
2023-05-23 09:17:58	100006	68 Maple Avenue Street	A cosmetic scuffs from a collision with a motorcycle	t
2022-11-06 16:45:26	100007	10 Second Avenue Street	A severe dents from a collision with a truck	f
2018-10-12 11:07:25	100007	30 Second Avenue Lane	A cosmetic bumps from a collision with a bike	f
2020-10-28 00:53:47	100007	70 Fifth Avenue Road	A severe damage from a collision with a car	t
2021-05-06 18:46:02	100003	70 Main Street Road	A major scratches from a collision with a motorcycle	f
2023-10-12 13:51:47	100012	86 Fourth Street Road	A cosmetic scuffs from a collision with a car	t
2023-03-13 04:05:11	100014	27 Main Street Avenue	A minor scratches from a collision with a motorcycle	f
2021-03-23 16:54:36	100001	6 Main Street Lane	A minor dents from a collision with a truck	t
2021-07-27 17:01:20	100002	81 Fourth Street Road	A cosmetic bumps from a collision with a car	f
2021-12-10 00:15:10	100010	28 Second Avenue Lane	A major bumps from a collision with a motorcycle	f
2019-05-11 00:09:57	100012	90 Park Avenue Road	A cosmetic scuffs from a collision with a truck	t
2023-04-20 05:55:15	100019	41 Fourth Street Street	A minor scratches from a collision with a bike	f
2021-01-26 17:52:45	100008	28 Fifth Avenue Street	A cosmetic scratches from a collision with a car	f
2019-07-17 12:17:38	100001	81 Fourth Street Street	A extensive scuffs from a collision with a motorcycle	f
2021-02-17 00:35:31	100014	96 Cedar Lane Road	A minor scuffs from a collision with a bike	t
2022-10-22 10:50:12	100011	3 Third Street Road	A cosmetic damage from a collision with a car	t
2020-01-25 07:42:05	100014	43 Third Street Lane	A extensive dents from a collision with a truck	t
2021-12-25 22:47:21	100012	48 Fourth Street Lane	A minor scuffs from a collision with a truck	t
2018-05-22 01:15:37	100008	89 Elm Street Road	A major scuffs from a collision with a car	f
2019-10-14 05:47:08	100018	88 First Avenue Street	A major scuffs from a collision with a motorcycle	t
2021-11-24 06:40:39	100011	51 Third Street Road	A severe scuffs from a collision with a bike	t
2023-04-12 14:53:55	100004	73 Cedar Lane Lane	A cosmetic scratches from a collision with a truck	f
2018-11-01 22:31:53	100013	68 Park Avenue Street	A major dents from a collision with a car	f
2022-01-30 19:37:08	100018	69 Cedar Lane Lane	A cosmetic scratches from a collision with a motorcycle	t
2022-06-22 01:03:39	100011	73 First Avenue Avenue	A minor scuffs from a collision with a bike	f
2023-03-18 02:12:37	100015	44 First Avenue Avenue	A minor scratches from a collision with a bike	t
2020-12-06 09:47:56	100020	46 Park Avenue Road	A minor dents from a collision with a motorcycle	t
2021-08-20 23:14:01	100005	38 Park Avenue Road	A severe scratches from a collision with a bike	t
2022-10-22 20:00:57	100001	32 Maple Avenue Street	A severe bumps from a collision with a car	f
2018-09-27 02:29:55	100005	71 Maple Avenue Lane	A cosmetic dents from a collision with a truck	f
2019-01-31 09:36:03	100015	74 Park Avenue Road	A minor damage from a collision with a bike	t
2019-08-11 04:07:35	100012	14 Cedar Lane Avenue	A cosmetic damage from a collision with a bike	t
2021-05-28 23:57:26	100002	45 Second Avenue Avenue	A severe scratches from a collision with a motorcycle	t
2021-02-06 02:10:46	100006	61 Third Street Avenue	A major dents from a collision with a bike	t
2022-10-31 03:57:51	100012	49 Fourth Street Avenue	A cosmetic dents from a collision with a motorcycle	f
2020-02-28 01:54:23	100008	10 Fourth Street Road	A severe dents from a collision with a motorcycle	t
2020-11-29 08:16:47	100007	63 Second Avenue Lane	A severe bumps from a collision with a bike	t
2021-10-06 05:19:53	100003	78 Fourth Street Lane	A minor scratches from a collision with a car	f
2022-06-01 13:21:27	100012	11 Main Street Street	A severe damage from a collision with a truck	t
2018-10-24 05:22:02	100017	94 Elm Street Lane	A extensive damage from a collision with a motorcycle	f
2021-02-09 08:18:47	100017	69 Third Street Road	A cosmetic damage from a collision with a motorcycle	f
2021-02-03 10:17:09	100004	90 Park Avenue Lane	A cosmetic scratches from a collision with a truck	f
2021-11-24 16:49:24	100006	23 Elm Street Avenue	A severe bumps from a collision with a bike	f
2018-11-07 06:17:21	100003	68 Fifth Avenue Street	A extensive dents from a collision with a motorcycle	f
2023-12-15 04:16:18	100010	63 Third Street Avenue	A major scuffs from a collision with a bike	t
2019-07-17 03:34:27	100001	24 Third Street Avenue	A cosmetic scratches from a collision with a motorcycle	t
2021-09-02 14:09:40	100005	25 Fifth Avenue Street	A extensive dents from a collision with a bike	t
2021-08-25 11:34:20	100016	92 Cedar Lane Road	A severe dents from a collision with a truck	f
2018-04-03 12:25:41	100017	70 First Avenue Lane	A minor dents from a collision with a motorcycle	t
2023-01-26 06:07:37	100020	15 Park Avenue Street	A cosmetic dents from a collision with a car	t
2019-02-18 00:30:46	100008	78 Third Street Avenue	A severe damage from a collision with a bike	t
2022-09-13 22:21:31	100007	68 Second Avenue Avenue	A extensive scuffs from a collision with a bike	f
2018-01-31 12:43:09	100016	72 Fifth Avenue Avenue	A cosmetic damage from a collision with a bike	f
2021-02-01 07:17:42	100004	93 Fourth Street Street	A extensive damage from a collision with a car	f
2022-09-24 23:31:48	100017	97 Third Street Avenue	A severe dents from a collision with a bike	f
2019-03-16 06:25:15	100007	69 Cedar Lane Road	A extensive bumps from a collision with a car	t
2020-11-27 12:10:15	100008	15 Second Avenue Lane	A cosmetic scuffs from a collision with a car	t
2023-09-22 15:20:49	100002	18 Elm Street Road	A cosmetic dents from a collision with a bike	f
2022-12-17 08:26:22	100004	62 Elm Street Lane	A cosmetic scuffs from a collision with a motorcycle	f
2023-02-16 05:49:57	100007	88 Elm Street Road	A cosmetic dents from a collision with a truck	f
2023-01-24 17:14:11	100020	64 Second Avenue Lane	A minor dents from a collision with a truck	t
2020-08-19 07:45:12	100005	37 Elm Street Avenue	A minor scratches from a collision with a truck	f
2023-10-05 04:43:56	100001	86 Main Street Road	A minor damage from a collision with a car	f
2023-05-15 20:41:11	100019	14 Cedar Lane Lane	A severe damage from a collision with a motorcycle	t
2021-02-16 17:22:55	100020	55 First Avenue Avenue	A minor dents from a collision with a car	f
2018-04-30 03:46:08	100018	36 Fifth Avenue Street	A extensive scratches from a collision with a bike	t
2020-12-25 15:28:37	100014	19 Third Street Lane	A extensive scratches from a collision with a truck	f
2018-11-18 12:07:05	100020	59 Third Street Road	A extensive scuffs from a collision with a car	f
2020-09-17 17:43:45	100011	68 Fifth Avenue Lane	A extensive damage from a collision with a bike	t
2018-12-31 14:54:37	100011	77 Park Avenue Lane	A minor scuffs from a collision with a motorcycle	f
2019-10-16 11:35:17	100005	62 Main Street Road	A major scratches from a collision with a motorcycle	f
2020-02-24 16:35:55	100004	59 Fourth Street Lane	A major scratches from a collision with a bike	t
2020-03-02 00:01:42	100017	47 Second Avenue Avenue	A severe scuffs from a collision with a truck	t
2023-06-25 10:39:29	100010	49 Cedar Lane Road	A minor bumps from a collision with a bike	t
2018-01-17 22:50:18	100008	49 Park Avenue Avenue	A cosmetic scuffs from a collision with a bike	t
2022-06-16 17:53:04	100016	24 Maple Avenue Road	A minor scratches from a collision with a motorcycle	f
2022-11-02 12:42:36	100015	37 Main Street Road	A minor damage from a collision with a car	f
2023-06-30 10:18:21	100011	86 Elm Street Avenue	A cosmetic scuffs from a collision with a motorcycle	t
2023-09-10 11:22:33	100010	12 Park Avenue Road	A extensive damage from a collision with a bike	t
2021-02-14 03:33:06	100019	85 First Avenue Lane	A minor damage from a collision with a motorcycle	t
2022-06-29 21:09:17	100020	8 Fourth Street Lane	A minor scuffs from a collision with a bike	t
2019-02-24 09:13:20	100002	24 Third Street Lane	A major bumps from a collision with a car	f
2023-05-01 13:28:56	100017	96 Cedar Lane Lane	A extensive scuffs from a collision with a motorcycle	f
2020-10-17 14:04:28	100011	67 Second Avenue Street	A severe dents from a collision with a motorcycle	f
2021-12-09 05:19:01	100016	30 Cedar Lane Avenue	A cosmetic dents from a collision with a bike	f
2021-08-25 15:17:30	100010	52 Park Avenue Street	A major scratches from a collision with a motorcycle	f
2019-03-17 06:07:51	100001	74 First Avenue Road	A extensive damage from a collision with a bike	t
2023-11-18 23:45:14	100007	25 Second Avenue Road	A major dents from a collision with a bike	f
2019-12-18 05:12:31	100002	37 Third Street Avenue	A cosmetic bumps from a collision with a car	f
2018-07-15 19:47:33	100010	61 Main Street Street	A minor scuffs from a collision with a car	f
2020-07-20 22:27:19	100019	11 Park Avenue Lane	A extensive scratches from a collision with a car	t
2022-04-01 01:19:21	100002	17 First Avenue Lane	A minor bumps from a collision with a car	t
2019-03-16 16:03:26	100001	12 Elm Street Avenue	A severe scratches from a collision with a car	t
2020-06-26 04:30:55	100002	92 Fourth Street Street	A cosmetic damage from a collision with a bike	t
2023-07-16 13:31:40	100013	4 Third Street Lane	A major scuffs from a collision with a bike	f
2019-09-21 14:54:44	100002	32 First Avenue Avenue	A minor scratches from a collision with a truck	t
2022-04-07 17:31:45	100010	90 Elm Street Street	A major bumps from a collision with a motorcycle	t
2019-05-19 19:07:27	100004	10 Second Avenue Road	A severe scuffs from a collision with a motorcycle	t
2022-08-09 19:20:24	100018	40 Maple Avenue Road	A extensive damage from a collision with a motorcycle	t
2018-03-05 14:01:06	100007	68 Second Avenue Street	A major damage from a collision with a car	t
2022-02-12 03:51:18	100015	41 Third Street Lane	A severe damage from a collision with a car	f
2023-03-14 03:37:27	100019	85 Fifth Avenue Road	A cosmetic dents from a collision with a car	f
2019-09-10 09:02:07	100003	92 First Avenue Road	A extensive dents from a collision with a motorcycle	t
2018-04-17 11:25:02	100019	45 Park Avenue Avenue	A extensive damage from a collision with a motorcycle	t
2023-07-25 20:05:22	100012	28 First Avenue Road	A minor dents from a collision with a bike	t
2022-05-03 05:55:26	100016	52 Park Avenue Avenue	A major dents from a collision with a bike	t
2022-06-09 07:31:57	100003	35 Third Street Avenue	A cosmetic scuffs from a collision with a motorcycle	t
2019-08-26 18:02:54	100014	37 Cedar Lane Lane	A extensive scuffs from a collision with a truck	t
2019-06-04 05:41:17	100017	5 Maple Avenue Street	A severe dents from a collision with a car	t
2023-05-14 07:33:39	100010	30 Cedar Lane Street	A extensive scuffs from a collision with a bike	f
2022-09-16 20:58:34	100007	96 Fourth Street Avenue	A major damage from a collision with a car	t
2020-11-06 17:57:23	100015	18 Elm Street Street	A severe damage from a collision with a motorcycle	t
2020-11-02 00:57:57	100006	23 Fifth Avenue Lane	A extensive scratches from a collision with a motorcycle	t
2020-01-20 14:31:51	100011	35 Fifth Avenue Street	A cosmetic damage from a collision with a motorcycle	f
2023-03-05 20:35:59	100011	8 Second Avenue Avenue	A cosmetic damage from a collision with a truck	t
2018-04-23 17:55:37	100015	50 Maple Avenue Lane	A minor damage from a collision with a car	t
2022-01-31 16:25:54	100003	26 Maple Avenue Avenue	A extensive scuffs from a collision with a car	t
2021-07-06 19:14:16	100002	84 Fifth Avenue Lane	A minor scuffs from a collision with a motorcycle	t
2019-11-18 04:49:43	100006	15 First Avenue Road	A cosmetic scuffs from a collision with a car	f
2021-09-05 12:06:02	100018	74 Second Avenue Avenue	A extensive scuffs from a collision with a truck	f
2021-10-23 04:08:48	100006	98 Fifth Avenue Lane	A major bumps from a collision with a motorcycle	f
2021-08-31 23:21:50	100008	32 Main Street Street	A severe bumps from a collision with a bike	f
2019-12-04 03:15:04	100008	2 First Avenue Lane	A major damage from a collision with a truck	t
2020-10-24 14:37:35	100019	9 Fifth Avenue Lane	A severe scratches from a collision with a car	t
2021-04-25 02:38:44	100017	4 First Avenue Street	A major bumps from a collision with a bike	t
2021-08-18 19:30:18	100002	84 Maple Avenue Avenue	A major scratches from a collision with a car	f
2023-05-19 02:20:05	100002	37 Park Avenue Road	A major scuffs from a collision with a motorcycle	t
2021-10-07 04:12:06	100014	54 Cedar Lane Avenue	A major scuffs from a collision with a bike	f
2019-10-02 15:43:18	100019	34 Elm Street Avenue	A severe dents from a collision with a motorcycle	f
\.


--
-- TOC entry 3440 (class 0 OID 33590)
-- Dependencies: 217
-- Data for Name: Auto; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Auto" ("Auto_Code", "Mod_Code", "Engine_Num", "Date_Last_TS", "Mileage", "Body_Num", "Release_Year", reg_plate, "Status") FROM stdin;
938227	345678	2DFCJ13421	2021-03-15 00:00:00	2098	WBABC1234567	2020	MH445K09	t
582891	456789	84GFDV8732	2019-09-22 00:00:00	4067	WDD123456789	2017	MK647A72	t
186549	567890	13ABCX9999	2022-01-05 00:00:00	739	JTJGZ8BC4G2000019	2020	HO912E72	t
375648	678901	89HFDK7924	2020-07-10 00:00:00	2815	SAJEA6AT3H8K37538	2021	HA867B18	t
802189	789012	62FDGA2973	2022-02-27 00:00:00	558	WP0AA2A7XGL108484	2017	MH114E90	t
205635	890123	25GFBC2891	2021-05-21 00:00:00	1392	5YJSA1E11HF185161	2019	HO438O54	t
324516	294832	22GFDK7311	2021-06-28 00:00:00	2785	WAUZZZ8VXDB107360	2015	MH329O91	t
903284	456789	59GHJL9384	2020-02-14 00:00:00	3528	WDD1240422A222157	2016	MK321B68	t
632489	567890	40DFCV1287	2022-03-10 00:00:00	1689	JTHKD5BHXD2161306	2021	HO790A41	t
482949	456789	43XEC92813	2021-01-21 00:00:00	2650	WDB12345678901234	2019	BA992H77	t
685726	345678	59CCG21125	2020-08-12 00:00:00	8500	WBAX1234567890123	2020	MO312K89	t
129303	678901	24WQA31411	2021-03-09 00:00:00	4920	SAJ12345678901234	2018	PA521B79	t
573083	345678	99XBS98732	2019-06-18 00:00:00	12300	WBAN123456789012	2019	BM938H87	t
237389	789012	03TRQ28657	2022-02-05 00:00:00	3100	WP0AB123456789012	2021	MP115S85	t
184729	678901	55LNU73305	2019-10-22 00:00:00	9720	SAJ12345678901235	2017	XA362M41	t
490100	567890	12SLW22980	2021-02-17 00:00:00	1870	JTH12345678901234	2022	MO992F48	t
837287	345678	78NTH43920	2019-04-29 00:00:00	8600	WBA12345678901234	2017	XM215H51	t
276172	345678	63QSF38120	2022-01-09 00:00:00	4600	WBA12345678901235	2021	BA573C49	t
881990	456789	87XNS46720	2020-12-02 00:00:00	9800	WDD12345678901234	2019	KA111R86	t
367932	890123	92BVA73328	2020-05-14 00:00:00	6300	5YJ12345678901234	2018	BM702F34	t
452145	294832	7JVJL38380	2021-01-21 00:00:00	5623	WBAYF4C54ED123456	2020	ХУ159Р11	t
312532	294832	52WVC10338	2020-12-12 00:00:00	1344	WAUZZZ8VXCA123456	2018	XO337P196	t
759321	901234	91CVFD8385	2023-06-01 00:00:00	5910	WA1LAAF77JD007402	2018	MK172B06	t
362718	456789	21BFD84117	2023-06-01 00:00:00	15600	WDB12345678901235	2017	BB042E34	t
776363	901234	38KPU98329	2023-06-01 00:00:00	13750	WA1L1234567890123	2020	PB776J39	t
872364	567890	5TGXX24323	2023-06-01 00:00:00	10856	JTJHY7AX4B4041234	2017	В369АМ199	t
287461	345678	D7FN908392	2023-06-01 00:00:00	15678	5UXXW5C56H0U12345	2016	К951КН19	t
721930	789012	6UJTT54253	2019-11-15 00:00:00	7409	WP0AB2A74BL123456	2011	М392ХМ123	f
437892	345678	32VFDK6749	2023-06-01 00:00:00	8053	WBA3D5C53EKX98023	2014	MH523E83	f
693246	890123	K6U2315266	2023-06-01 00:00:00	4789	5YJSA1DN8CFP12345	2013	ЕХ437Х77	f
539481	901234	KAA4427606	2023-06-01 00:00:00	29750	WA1CVAFP5AA098765	2011	У007УХ36	f
972841	456789	N97F30E433	2023-06-01 00:00:00	8935	WDDKK5GF5BF123456	2014	А717АР26	f
\.


--
-- TOC entry 3441 (class 0 OID 33594)
-- Dependencies: 218
-- Data for Name: Bonus_Card; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Bonus_Card" ("BC_Code", "Cl_Code", "Bonus_Sum") FROM stdin;
1234567890123456	23456	10000
2345678901234567	34567	5000
3456789012345678	45678	7500
4567890123456789	56789	20000
5678901234567890	67890	15000
6789012345678901	78901	30000
7890123456789012	69690	7500
8901234567890123	22130	12500
9012345678901234	11223	5000
123456789012345	22334	2500
\.


--
-- TOC entry 3442 (class 0 OID 33598)
-- Dependencies: 219
-- Data for Name: Client; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Client" ("Cl_Code", "Email", "Address", "Full_Name", "Passport_Data", "Tel_Num") FROM stdin;
12345	john.doe@gmail.com	123 Main St, Anytown, USA	John Doe	1234567890	71234567890
23456	jane.smith@yahoo.com	456 Elm St, Anytown, USA	Jane Smith	2345678901	71234567891
34567	bob.jones@hotmail.com	789 Maple Ave, Anytown, USA	Bob Jones	3456789012	71234567892
45678	ligma.johnson@aol.com	321 Oak St, Oklahoma, USA	Ligma Johnson	4567890123	71234567893
56789	jim.smith@gmail.com	456 Cedar Ave, Anytown, USA	Jim Smith	5678901234	71234567894
67890	sara.doe@yahoo.com	789 Oak St, Anytown, USA	Sara Doe	6789012345	71234567895
78901	mike.jones@hotmail.com	123 Elm St, Anytown, USA	Mike Jones	7890123456	71234567896
89012	jane.doe@aol.com	321 Maple Ave, Anytown, USA	Jane Doe	8901234567	71234567897
69690	daniel.walker@gmail.com	555 Oak St, Anytown, USA	Daniel Walker	4352999666	72201002958
22130	tommie.hilfigger@yahoo.com	777 Elm St, Anytown, USA	Tommy Hilfigger	5782374837	79992131230
11223	bruce.wayne@hotmail.com	444 Main St, Gotham City	Bruce Wayne	1122334455	71234567900
22334	clark.kent@aol.com	555 Elm St, Metropolis	Clark Kent	2233445566	71234567901
12346	jessica.johnson@gmail.com	456 Main St, Anytown, USA	Jessica Johnson	4444444444	71234567899
23457	david.lee@yahoo.com	789 Elm St, Anytown, USA	David Lee	5555555555	71234567908
34568	amy.brown@hotmail.com	321 Maple Ave, Anytown, USA	Amy Brown	6666666666	71234567917
45679	michael.chang@gmail.com	555 Cedar Ave, Anytown, USA	Michael Chang	7777777777	71234567926
56790	mary.smith@yahoo.com	789 Oak St, Anytown, USA	Mary Smith	8888888888	71234567935
67891	timothy.jones@hotmail.com	123 Main St, Anytown, USA	Timothy Jones	9999999999	71234567944
78902	lisa.doe@aol.com	321 Maple Ave, Anytown, USA	Lisa Doe	1234432156	71234567953
89013	william.walker@gmail.com	555 Oak St, Anytown, USA	William Walker	6789067890	71234567962
90124	emma.hilfigger@yahoo.com	777 Elm St, Anytown, USA	Emma Hilfigger	5555444444	72201002959
11234	peter.parker@hotmail.com	444 Main St, New York City	Peter Parker	6789678967	71234567971
22345	tony.stark@aol.com	555 Elm St, Malibu	Tony Stark	1234237890	71234567980
33456	bruce.banner@gmail.com	789 Maple Ave, Anytown, USA	Bruce Banner	2333678901	71234567999
44567	steve.rogers@yahoo.com	123 Oak St, Brooklyn	Steve Rogers	3451569012	71234568006
55678	natasha.romanoff@hotmail.com	321 Cedar Ave, Moscow	Natasha Romanoff	4567824123	71234568015
66789	thor.odinson@gmail.com	789 Maple Ave, Asgard	Thor Odinson	5653901234	71234568024
\.


--
-- TOC entry 3443 (class 0 OID 33604)
-- Dependencies: 220
-- Data for Name: Contract; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Contract" ("Contr_Code", "Act_Transf_Client", "Act_Transf_Company", "Rent_Price", "DT_Contract", "DT_Car_Transf_To_Cl", "Factual_DT_Ret", "Late_Fee", "Ret_Mark", "Cl_Code", "Stf_Code", "Auto_Code", rent_time) FROM stdin;
100001	128132	128133	25	2019-01-12 12:31:52	2019-01-12 13:52:16	2019-01-13 12:00:21	\N	t	45678	123123	312532	24
100002	128133	128134	30	2019-02-14 09:45:31	2019-02-14 11:15:22	2019-02-15 09:50:13	\N	t	23456	456789	938227	48
100003	128135	128136	35	2019-03-20 15:22:11	2019-03-23 16:45:39	2019-03-22 14:17:55	25	t	34567	134523	186549	72
100004	128136	128137	45	2019-04-25 10:10:00	2019-04-25 11:45:22	2019-04-26 09:55:00	\N	t	45678	456789	375648	24
100005	128137	128138	50	2019-05-16 14:30:00	2019-05-16 16:00:00	2019-05-18 14:30:00	10	t	56789	113322	573083	48
100006	128139	128140	20	2019-06-22 09:00:00	2019-06-22 11:00:00	2019-06-23 12:00:00	\N	t	67890	123123	632489	24
100007	128141	128142	25	2019-07-14 12:00:00	2019-07-14 14:00:00	2019-07-15 12:00:00	5	t	78901	134523	482949	24
100008	128143	128144	40	2019-08-28 16:00:00	2019-08-28 17:30:00	2019-08-29 16:00:00	\N	t	89012	456789	685726	48
100010	128154	128155	40	2019-10-18 14:10:22	2019-10-18 15:30:45	2019-10-20 14:45:20	\N	t	78901	113322	903284	48
100011	128155	128156	30	2019-11-22 11:45:10	2019-11-22 12:50:20	2019-11-25 11:20:10	\N	t	11223	134523	776363	72
100012	128156	128157	25	2019-12-25 09:00:00	2019-12-25 10:30:15	2019-12-26 09:15:00	\N	t	22334	123123	129303	24
100013	128157	128158	35	2020-01-31 13:20:45	2020-01-31 14:45:30	2020-02-01 13:30:00	\N	t	45679	134523	573083	24
100014	128158	128159	40	2020-03-10 16:55:00	2020-03-10 18:15:25	2020-03-11 16:40:00	5	t	34568	456789	129303	48
100015	128160	128161	30	2020-04-15 11:20:00	2020-04-15 12:30:45	2020-04-16 12:30:00	\N	t	12345	123123	938227	24
100016	128161	128162	35	2020-05-20 09:10:00	2020-05-20 10:40:20	2020-05-21 09:50:00	\N	t	34567	134523	186549	48
100017	128163	128164	25	2020-06-25 14:30:00	2020-06-25 16:00:15	2020-06-26 13:45:00	\N	t	45678	456789	375648	24
100018	128162	128163	40	2020-05-20 11:30:00	2020-05-20 12:45:00	2020-05-21 11:20:00	10	t	23456	123123	312532	24
100019	128164	128165	35	2020-06-18 09:00:00	2020-06-18 10:15:00	2020-06-20 08:45:00	\N	f	34567	134523	186549	48
100020	128166	128167	45	2020-07-25 14:00:00	2020-07-25 15:30:00	2020-07-26 14:15:00	\N	t	45678	456789	375648	24
100021	128133	128134	25	2023-05-29 12:29:12	2023-05-29 13:59:16	2023-05-29 16:50:21	\N	t	11223	456789	938227	3
100022	128134	128135	25	2023-05-29 20:00:54	2023-05-29 20:05:16	2023-05-31 19:29:21	\N	t	11223	456789	938227	24
100023	128135	128136	25	2023-05-29 15:00:54	2023-05-29 15:05:16	\N	\N	f	45678	456789	582891	48
100024	128136	128137	25	2023-05-29 02:00:53	2023-05-29 02:15:55	2023-05-29 07:55:55	\N	t	22334	678901	186549	6
100025	128137	128138	25	2023-05-29 10:30:00	2023-05-29 11:00:00	2023-05-29 20:55:00	\N	t	23457	567890	490100	10
100026	128138	128139	25	2023-05-29 14:00:00	2023-05-29 15:00:00	2023-05-30 09:11:00	\N	t	34568	123123	693246	20
100027	128139	128140	25	2023-05-29 09:30:00	2023-05-29 10:00:00	2023-05-29 19:11:00	\N	t	34567	567890	802189	18
100028	128140	128141	25	2023-05-29 16:00:00	2023-05-29 16:30:00	2023-05-29 23:45:00	\N	t	78901	567890	881990	8
100029	128141	128142	25	2023-05-29 13:00:00	2023-05-29 13:30:00	2023-05-30 00:35:00	\N	t	22130	123123	693246	12
100030	128142	128143	25	2023-05-29 19:30:00	2023-05-29 20:00:00	2023-05-30 09:45:00	\N	t	23457	123123	437892	12
100031	128143	128144	25	2023-05-29 15:30:00	2023-05-29 16:00:00	2023-05-29 23:30:00	\N	t	34568	123123	903284	9
100032	128144	128145	25	2023-05-29 10:00:00	2023-05-29 10:30:00	2023-05-29 18:45:00	100	t	11234	123123	632489	7
100033	128145	128146	25	2023-05-29 17:00:00	2023-05-29 17:30:00	2023-05-30 01:15:00	\N	t	90124	123123	482949	8
100034	128146	128147	25	2023-05-29 14:30:00	2023-05-29 15:00:00	2023-05-29 22:45:00	\N	t	55678	123123	685726	9
100036	128168	\N	950	2023-06-08 07:46:01	2023-06-08 08:10:00	2023-06-08 19:30:00	100	t	23456	123123	776363	10
100035	128167	\N	1000	2023-06-08 07:45:03.1	2023-06-08 08:00:00	2023-06-08 15:30:00	\N	t	12345	123123	539481	10
100037	128169	\N	732	2023-06-08 12:37:03.4	2023-06-08 12:40:00	2023-06-09 18:30:00	1540	t	11223	123123	490100	10
\.


--
-- TOC entry 3444 (class 0 OID 33607)
-- Dependencies: 221
-- Data for Name: Extension; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Extension" ("Extension_Id", "Contr_Code", "New_DT_Ret", "Ext_Hours", "Sequence_Num") FROM stdin;
1	100001	2019-01-13 14:52:16	1	1
2	100001	2019-01-13 15:52:16	2	2
3	100001	2019-01-13 16:52:16	3	3
4	100001	2019-01-13 17:52:16	4	4
5	100001	2019-01-13 18:52:16	5	5
6	100001	2019-01-13 19:52:16	6	6
7	100001	2019-01-13 20:52:16	7	7
8	100001	2019-01-13 21:52:16	8	8
9	100001	2019-01-13 22:52:16	9	9
10	100001	2019-01-13 23:52:16	10	10
11	100002	2019-02-16 12:15:22	1	1
12	100002	2019-02-16 13:15:22	2	2
13	100002	2019-02-16 14:15:22	3	3
14	100002	2019-02-16 15:15:22	4	4
21	100003	2019-03-26 17:45:39	1	1
22	100003	2019-03-26 18:45:39	2	2
23	100003	2019-03-26 19:45:39	3	3
24	100003	2019-03-26 20:45:39	4	4
25	100003	2019-03-26 21:45:39	5	5
26	100003	2019-03-26 22:45:39	6	6
27	100003	2019-03-26 23:45:39	7	7
28	100003	2019-03-27 00:45:39	8	8
29	100003	2019-03-27 01:45:39	9	9
30	100003	2019-03-27 02:45:39	10	10
31	100004	2019-04-26 12:45:22	1	1
32	100004	2019-04-26 13:45:22	2	2
33	100004	2019-04-26 14:45:22	3	3
34	100004	2019-04-26 15:45:22	4	4
35	100004	2019-04-26 16:45:22	5	5
36	100004	2019-04-26 17:45:22	6	6
37	100004	2019-04-26 18:45:22	7	7
38	100004	2019-04-26 19:45:22	8	8
39	100004	2019-04-26 20:45:22	9	9
40	100004	2019-04-26 21:45:22	10	10
41	100005	2019-05-18 17:00:00	1	1
42	100005	2019-05-18 18:00:00	2	2
43	100005	2019-05-18 19:00:00	3	3
44	100005	2019-05-18 20:00:00	4	4
45	100005	2019-05-18 21:00:00	5	5
46	100005	2019-05-18 22:00:00	6	6
47	100005	2019-05-18 23:00:00	7	7
48	100005	2019-05-19 00:00:00	8	8
49	100005	2019-05-19 01:00:00	9	9
50	100005	2019-05-19 02:00:00	10	10
51	100006	2019-06-23 12:00:00	1	1
52	100006	2019-06-23 13:00:00	2	2
53	100006	2019-06-23 14:00:00	3	3
54	100006	2019-06-23 15:00:00	4	4
55	100006	2019-06-23 16:00:00	5	5
56	100006	2019-06-23 17:00:00	6	6
57	100006	2019-06-23 18:00:00	7	7
58	100006	2019-06-23 19:00:00	8	8
59	100006	2019-06-23 20:00:00	9	9
60	100006	2019-06-23 21:00:00	10	10
61	100007	2019-07-15 15:00:00	1	1
62	100007	2019-07-15 16:00:00	2	2
63	100007	2019-07-15 17:00:00	3	3
64	100007	2019-07-15 18:00:00	4	4
65	100007	2019-07-15 19:00:00	5	5
66	100007	2019-07-15 20:00:00	6	6
67	100007	2019-07-15 21:00:00	7	7
68	100007	2019-07-15 22:00:00	8	8
69	100007	2019-07-15 23:00:00	9	9
70	100007	2019-07-16 00:00:00	10	10
71	100008	2019-08-30 18:30:00	1	1
72	100008	2019-08-30 19:30:00	2	2
73	100008	2019-08-30 20:30:00	3	3
74	100008	2019-08-30 21:30:00	4	4
75	100008	2019-08-30 22:30:00	5	5
76	100008	2019-08-30 23:30:00	6	6
77	100008	2019-08-31 00:30:00	7	7
78	100008	2019-08-31 01:30:00	8	8
79	100008	2019-08-31 02:30:00	9	9
80	100008	2019-08-31 03:30:00	10	10
81	100010	2019-10-20 16:30:45	1	1
82	100010	2019-10-20 17:30:45	2	2
83	100010	2019-10-20 18:30:45	3	3
84	100010	2019-10-20 19:30:45	4	4
85	100010	2019-10-20 20:30:45	5	5
86	100010	2019-10-20 21:30:45	6	6
87	100010	2019-10-20 22:30:45	7	7
88	100010	2019-10-20 23:30:45	8	8
89	100010	2019-10-21 00:30:45	9	9
90	100010	2019-10-21 01:30:45	10	10
91	100011	2019-11-25 13:50:20	1	1
92	100011	2019-11-25 14:50:20	2	2
93	100011	2019-11-25 15:50:20	3	3
94	100011	2019-11-25 16:50:20	4	4
95	100011	2019-11-25 17:50:20	5	5
96	100011	2019-11-25 18:50:20	6	6
97	100011	2019-11-25 19:50:20	7	7
98	100011	2019-11-25 20:50:20	8	8
99	100011	2019-11-25 21:50:20	9	9
100	100011	2019-11-25 22:50:20	10	10
101	100012	2019-12-26 11:30:15	1	1
102	100012	2019-12-26 12:30:15	2	2
103	100012	2019-12-26 13:30:15	3	3
104	100012	2019-12-26 14:30:15	4	4
105	100012	2019-12-26 15:30:15	5	5
106	100012	2019-12-26 16:30:15	6	6
107	100012	2019-12-26 17:30:15	7	7
108	100012	2019-12-26 18:30:15	8	8
109	100012	2019-12-26 19:30:15	9	9
110	100012	2019-12-26 20:30:15	10	10
111	100013	2020-02-01 15:45:30	1	1
112	100013	2020-02-01 16:45:30	2	2
113	100013	2020-02-01 17:45:30	3	3
114	100013	2020-02-01 18:45:30	4	4
115	100013	2020-02-01 19:45:30	5	5
116	100013	2020-02-01 20:45:30	6	6
117	100013	2020-02-01 21:45:30	7	7
118	100013	2020-02-01 22:45:30	8	8
119	100013	2020-02-01 23:45:30	9	9
120	100013	2020-02-02 00:45:30	10	10
121	100014	2020-03-12 19:15:25	1	1
122	100014	2020-03-12 20:15:25	2	2
123	100014	2020-03-12 21:15:25	3	3
124	100014	2020-03-12 22:15:25	4	4
125	100014	2020-03-12 23:15:25	5	5
126	100014	2020-03-13 00:15:25	6	6
127	100014	2020-03-13 01:15:25	7	7
128	100014	2020-03-13 02:15:25	8	8
129	100014	2020-03-13 03:15:25	9	9
130	100014	2020-03-13 04:15:25	10	10
131	100015	2020-04-16 13:30:45	1	1
132	100015	2020-04-16 14:30:45	2	2
133	100015	2020-04-16 15:30:45	3	3
134	100015	2020-04-16 16:30:45	4	4
135	100015	2020-04-16 17:30:45	5	5
136	100015	2020-04-16 18:30:45	6	6
137	100015	2020-04-16 19:30:45	7	7
138	100015	2020-04-16 20:30:45	8	8
139	100015	2020-04-16 21:30:45	9	9
140	100015	2020-04-16 22:30:45	10	10
141	100016	2020-05-22 11:40:20	1	1
142	100016	2020-05-22 12:40:20	2	2
143	100016	2020-05-22 13:40:20	3	3
144	100016	2020-05-22 14:40:20	4	4
145	100016	2020-05-22 15:40:20	5	5
146	100016	2020-05-22 16:40:20	6	6
147	100016	2020-05-22 17:40:20	7	7
148	100016	2020-05-22 18:40:20	8	8
149	100016	2020-05-22 19:40:20	9	9
150	100016	2020-05-22 20:40:20	10	10
151	100017	2020-06-26 17:00:15	1	1
152	100017	2020-06-26 18:00:15	2	2
153	100017	2020-06-26 19:00:15	3	3
154	100017	2020-06-26 20:00:15	4	4
155	100017	2020-06-26 21:00:15	5	5
156	100017	2020-06-26 22:00:15	6	6
157	100017	2020-06-26 23:00:15	7	7
158	100017	2020-06-27 00:00:15	8	8
159	100017	2020-06-27 01:00:15	9	9
160	100017	2020-06-27 02:00:15	10	10
161	100018	2020-05-21 13:45:00	1	1
162	100018	2020-05-21 14:45:00	2	2
163	100018	2020-05-21 15:45:00	3	3
164	100018	2020-05-21 16:45:00	4	4
165	100018	2020-05-21 17:45:00	5	5
166	100018	2020-05-21 18:45:00	6	6
167	100018	2020-05-21 19:45:00	7	7
168	100018	2020-05-21 20:45:00	8	8
169	100018	2020-05-21 21:45:00	9	9
170	100018	2020-05-21 22:45:00	10	10
171	100019	2020-06-20 11:15:00	1	1
172	100019	2020-06-20 12:15:00	2	2
173	100019	2020-06-20 13:15:00	3	3
174	100019	2020-06-20 14:15:00	4	4
175	100019	2020-06-20 15:15:00	5	5
176	100019	2020-06-20 16:15:00	6	6
177	100019	2020-06-20 17:15:00	7	7
178	100019	2020-06-20 18:15:00	8	8
179	100019	2020-06-20 19:15:00	9	9
180	100019	2020-06-20 20:15:00	10	10
181	100020	2020-07-26 16:30:00	1	1
182	100020	2020-07-26 17:30:00	2	2
183	100020	2020-07-26 18:30:00	3	3
184	100020	2020-07-26 19:30:00	4	4
185	100020	2020-07-26 20:30:00	5	5
186	100020	2020-07-26 21:30:00	6	6
187	100020	2020-07-26 22:30:00	7	7
188	100020	2020-07-26 23:30:00	8	8
189	100020	2020-07-27 00:30:00	9	9
190	100020	2020-07-27 01:30:00	10	10
\.


--
-- TOC entry 3445 (class 0 OID 33610)
-- Dependencies: 222
-- Data for Name: Model; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Model" ("Mod_Code", "Name", "Characteristics", "Description", "Market_Price", "Bail_Sum") FROM stdin;
294832	Audi A6	Engine: 3.0L V6, Transmission: 8-speed automatic, Horsepower: 335, Torque: 369 lb-ft, Fuel Economy: 22 mpg city / 29 mpg hwy, Drive Type: All Wheel Drive	The Audi A6 is a mid-size luxury sedan that features cutting-edge technology and sleek design. With its powerful engine, smooth ride, and spacious interior, its the perfect car for those who want a balance of comfort and performance.	110000	1000
678901	Jaguar F-Type	Engine: 2.0L 4-cylinder, 296 hp. Transmission: 8-speed automatic. Drivetrain: Rear-wheel drive. Fuel economy: 23/30 mpg. Seating: 2. Cargo volume: 14.4 cubic feet.	The Jaguar F-Type is a luxury sports car that offers a sleek and sexy design, lively and agile handling, and a range of powerful engine options.	68000	680
789012	Porsche Panamera	Engine: 2.9L V6, 325 hp. Transmission: 8-speed automatic. Drivetrain: Rear-wheel drive. Fuel economy: 19/27 mpg. Seating: 4. Cargo volume: 17.6 cubic feet.	The Porsche Panamera is a luxury large car that offers a thrilling and engaging driving experience, top-notch interior, and impressive performance.	123750	1240
345678	BMW X5	Engine: 3.0L 6-cylinder, 300 hp. Transmission: 8-speed automatic. Drivetrain: All-wheel drive. Fuel economy: 20/27 mpg. Seating: 5. Cargo volume: 72.3 cubic feet.	The BMW X5 is a luxury midsize SUV that offers a sporty and dynamic driving experience, premium interior, and advanced technology features.	95900	1160
456789	Mercedes-Benz E-Class	Engine: 2.0L 4-cylinder, 255 hp. Transmission: 9-speed automatic. Drivetrain: Rear-wheel drive. Fuel economy: 21/30 mpg. Seating: 5. Cargo volume: 13.1 cubic feet.	The Mercedes-Benz E-Class is a luxury midsize car that offers a comfortable and high-tech interior, refined ride, and a wide range of engine options.	56750	770
567890	Lexus LS	Engine: 3.5L V6, 416 hp. Transmission: 10-speed automatic. Drivetrain: Rear-wheel drive. Fuel economy: 19/30 mpg. Seating: 5. Cargo volume: 16.95 cubic feet.	The Lexus LS is a luxury large car that offers a spacious and well-crafted interior, comfortable ride, and advanced safety features.	70000	900
890123	Tesla Model S	Motor: Electric, 670 hp. Transmission: Single-speed direct drive. Drivetrain: All-wheel drive. Range: 412 miles. Seating: 5. Cargo volume: 28.4 cubic feet.	The Tesla Model S is an all-electric luxury sedan that offers a futuristic and minimalist interior, lightning-fast acceleration, and cutting-edge technology features.	91300	1130
901234	Audi Q7	Engine: 3.0L V6, 335 hp. Transmission: 8-speed automatic. Drivetrain: All-wheel drive. Fuel economy: 18/23 mpg. Seating: 7. Cargo volume: 69.9 cubic feet.	The Audi Q7 is a luxury midsize SUV that offers a spacious and versatile interior, smooth and composed ride, and a range of advanced safety and technology features.	54300	750
\.


--
-- TOC entry 3446 (class 0 OID 33615)
-- Dependencies: 223
-- Data for Name: Penalties; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Penalties" ("Penalty_Code", "Accident_DT", "Who_Pays", "Payment_Status", "Penalty_Sum") FROM stdin;
101	2023-03-13 04:05:11	Cl	t	775.91
102	2019-07-17 03:34:27	Cl	t	342.56
103	2023-03-18 02:12:37	Co	t	352.16
104	2021-01-26 17:52:45	Ot	t	787.2
105	2018-01-17 11:40:00	Ot	t	50.96
106	2019-05-12 05:45:24	Co	t	240.68
107	2020-07-20 22:27:19	Ot	t	897.62
108	2020-11-10 12:41:37	Cl	t	705.84
109	2019-12-19 19:14:05	Cl	t	978.71
110	2023-05-15 20:41:11	Cl	t	810.03
111	2023-10-12 13:51:47	Co	t	920.81
112	2021-09-15 20:29:29	Cl	t	479.59
113	2020-02-28 01:54:23	Cl	t	162.91
114	2020-11-04 22:05:37	Ot	t	313.58
115	2021-06-26 10:01:46	Cl	t	382.79
116	2018-04-07 23:01:37	Ot	t	844.72
117	2020-04-08 13:07:54	Co	t	31.4
118	2020-09-03 07:39:11	Ot	t	367.41
119	2022-11-02 12:42:36	Co	t	383.78
120	2018-11-18 12:07:05	Ot	t	423.66
121	2021-11-29 02:39:40	Co	t	137.56
122	2019-06-04 05:41:17	Ot	t	984.77
123	2021-08-31 23:21:50	Cl	t	585.26
124	2019-10-16 11:35:17	Cl	t	250.44
125	2020-10-28 00:53:47	Co	t	76.11
126	2022-09-16 20:58:34	Co	t	414.38
127	2021-08-31 23:21:50	Cl	t	58.2
128	2020-10-17 14:04:28	Co	t	354.41
129	2021-09-30 22:29:37	Cl	t	524.87
130	2019-03-17 06:07:51	Cl	t	692.03
131	2019-02-24 09:13:20	Cl	t	692.26
132	2018-02-24 01:27:08	Ot	t	722.66
133	2020-09-23 05:42:30	Co	t	484.34
134	2022-08-03 01:38:50	Cl	t	895.57
135	2020-07-20 22:27:19	Co	t	555.55
136	2023-05-23 09:17:58	Co	t	137.38
137	2020-06-20 18:38:22	Ot	t	20.96
138	2018-10-24 05:22:02	Ot	t	908.04
139	2023-12-05 10:33:49	Ot	t	977.92
140	2019-10-07 10:59:26	Cl	t	117.24
141	2018-03-05 14:01:06	Ot	t	91.65
142	2018-05-22 01:15:37	Ot	t	990.97
143	2018-11-18 12:07:05	Co	t	69.03
144	2023-02-16 05:49:57	Ot	t	478.98
145	2022-07-09 06:52:58	Ot	t	298.16
146	2023-10-05 04:43:56	Cl	t	90.51
147	2021-12-25 22:47:21	Co	t	650.19
148	2020-02-28 01:54:23	Ot	t	967.92
149	2020-03-02 00:01:42	Co	t	338.53
150	2020-01-20 14:31:51	Co	t	635.69
151	2020-02-28 01:54:23	Cl	t	748.36
152	2019-06-04 05:41:17	Co	t	384.64
153	2021-02-06 02:10:46	Ot	t	93.31
154	2022-11-11 07:13:46	Cl	t	371.13
155	2022-06-29 21:09:17	Cl	t	802.83
156	2022-07-09 06:52:58	Cl	t	317.23
157	2020-10-24 14:37:35	Cl	t	764.26
158	2019-10-17 16:58:38	Co	t	997.49
159	2018-01-31 12:43:09	Cl	t	361.39
160	2018-08-10 00:30:08	Ot	t	547.05
161	2021-08-18 19:30:18	Ot	t	435.8
162	2020-09-03 07:39:11	Ot	t	589.17
163	2020-06-26 04:30:55	Cl	t	265.95
164	2018-08-10 00:30:08	Ot	t	246.03
165	2018-11-01 22:31:53	Ot	t	341.04
166	2022-08-03 01:38:50	Co	t	376.71
167	2021-01-09 02:15:01	Cl	t	845.15
168	2018-07-05 12:42:25	Ot	t	193.76
169	2022-06-01 13:21:27	Ot	t	974.44
170	2021-01-09 02:15:01	Cl	t	183.08
171	2023-06-04 11:26:51	Ot	t	986.47
172	2023-01-26 06:07:37	Ot	t	611.45
173	2023-06-30 10:18:21	Co	t	451.14
174	2019-08-14 10:40:44	Ot	t	715.44
175	2019-07-15 08:04:04	Co	t	493.3
176	2020-06-26 04:30:55	Cl	t	259.51
177	2019-11-18 04:49:43	Cl	t	292.48
178	2019-09-10 09:02:07	Co	t	341.71
179	2021-12-10 00:15:10	Cl	t	987.49
180	2021-09-15 20:29:29	Ot	t	58.19
181	2019-08-11 04:07:35	Cl	t	814.88
182	2020-12-06 09:47:56	Co	t	250.28
183	2018-04-23 17:55:37	Ot	t	379.48
184	2019-10-14 05:47:08	Cl	t	396.42
185	2023-05-14 07:33:39	Ot	t	439.74
186	2021-04-25 02:38:44	Cl	t	953.25
187	2019-02-24 09:13:20	Ot	t	765.14
188	2021-12-09 05:19:01	Ot	t	564.64
189	2020-09-03 07:39:11	Ot	t	407.34
190	2022-06-22 01:03:39	Co	t	738.8
191	2019-07-17 03:34:27	Co	t	320.53
192	2022-01-31 16:25:54	Cl	t	113.75
193	2023-10-12 13:51:47	Ot	t	252
194	2023-01-24 17:14:11	Ot	t	723.44
195	2018-11-18 12:07:05	Ot	t	411.69
196	2019-05-19 19:07:27	Cl	t	891.16
197	2021-05-06 18:46:02	Ot	t	24.09
198	2022-10-31 03:57:51	Ot	t	985.05
199	2022-06-01 13:21:27	Ot	t	542.6
200	2020-03-02 00:01:42	Co	t	598.14
201	2023-03-14 03:37:27	Cl	t	567.28
202	2023-09-22 15:20:49	Ot	t	288.76
203	2021-06-26 10:01:46	Ot	t	531.7
204	2018-07-15 19:47:33	Co	t	317.25
205	2020-11-10 12:41:37	Co	t	732.06
206	2021-09-05 12:06:02	Ot	t	225.35
207	2021-11-01 06:58:08	Cl	t	161.76
208	2020-05-29 01:19:14	Cl	t	618.85
209	2019-07-15 08:04:04	Ot	t	213.64
210	2018-04-07 23:01:37	Co	t	367.78
211	2022-06-16 17:53:04	Co	t	918.53
212	2022-09-24 23:31:48	Cl	t	873.09
213	2018-09-27 02:29:55	Co	t	455.55
214	2019-12-04 03:15:04	Ot	t	170.62
215	2018-12-11 07:47:56	Cl	t	620.89
216	2021-09-02 14:09:40	Co	t	594.98
217	2023-05-19 02:20:05	Cl	t	992.12
218	2018-03-05 14:01:06	Cl	t	934.91
219	2023-12-05 10:33:49	Ot	t	403.35
220	2021-10-23 04:08:48	Cl	f	338.82
\.


--
-- TOC entry 3447 (class 0 OID 33619)
-- Dependencies: 224
-- Data for Name: Price; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Price" ("Mod_Code", "DT_Inter_Start", "DT_Inter_End", "Price_One_H", "Price_Long_Inter", "Price_Code") FROM stdin;
294832	2023-05-29 12:12:12	\N	101	2160	7267
678901	2023-05-29 10:11:12	\N	88	1920	7268
345678	2023-05-29 09:11:00	\N	97	2280	7269
456789	2023-05-29 14:15:16	\N	80	1680	7270
901234	2023-05-29 08:12:13	\N	100	2160	7271
789012	2023-05-29 09:12:13	\N	82	1872	7272
567890	2023-05-29 11:11:11	\N	77	1680	7273
890123	2023-05-29 14:13:12	\N	84	1944	7274
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	88	2112	4860
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	54	1296	4861
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	97	2328	4862
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	68	1632	4863
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	80	1920	4864
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	83	1992	4865
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	51	1224	4866
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	80	1920	4867
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	82	1968	4868
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	79	1896	4869
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	50	1200	4870
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	53	1272	4871
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	68	1632	4872
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	86	2064	4873
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	90	2160	4874
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	59	1416	4875
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	51	1224	4876
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	96	2304	4877
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	51	1224	4878
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	88	2112	4879
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	97	2328	4880
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	68	1632	4881
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	74	1776	4882
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	93	2232	4883
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	64	1536	4884
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	89	2136	4885
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	58	1392	4886
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	95	2280	4887
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	67	1608	4888
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	55	1320	4889
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	84	2016	4890
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	75	1800	4891
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	68	1632	4892
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	53	1272	4893
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	77	1848	4894
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	96	2304	4895
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	63	1512	4896
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	76	1824	4897
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	89	2136	4898
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	86	2064	4899
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	55	1320	4900
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	63	1512	4901
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	51	1224	4902
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	69	1656	4903
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	65	1560	4904
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	92	2208	4905
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	72	1728	4906
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	96	2304	4907
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	74	1776	4908
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	70	1680	4909
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	91	2184	4910
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	60	1440	4911
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	97	2328	4912
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	69	1656	4913
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	62	1488	4914
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	64	1536	4915
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	85	2040	4916
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	69	1656	4917
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	79	1896	4918
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	56	1344	4919
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	94	2256	4920
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	79	1896	4921
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	98	2352	4922
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	56	1344	4923
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	96	2304	4924
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	51	1224	4925
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	92	2208	4926
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	99	2376	4927
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	64	1536	4928
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	75	1800	4929
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	51	1224	4930
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	80	1920	4931
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	77	1848	4932
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	95	2280	4933
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	75	1800	4934
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	52	1248	4935
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	55	1320	4936
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	65	1560	4937
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	82	1968	4938
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	62	1488	4939
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	78	1872	4940
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	61	1464	4941
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	92	2208	4942
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	84	2016	4943
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	55	1320	4944
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	59	1416	4945
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	53	1272	4946
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	78	1872	4947
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	61	1464	4948
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	84	2016	4949
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	93	2232	4950
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	56	1344	4951
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	88	2112	4952
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	77	1848	4953
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	75	1800	4954
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	98	2352	4955
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	62	1488	4956
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	80	1920	4957
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	53	1272	4958
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	98	2352	4959
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	71	1704	4960
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	94	2256	4961
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	66	1584	4962
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	52	1248	4963
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	81	1944	4964
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	88	2112	4965
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	100	2400	4966
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	61	1464	4967
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	88	2112	4968
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	70	1680	4969
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	63	1512	4970
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	78	1872	4971
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	94	2256	4972
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	86	2064	4973
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	73	1752	4974
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	63	1512	4975
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	70	1680	4976
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	85	2040	4977
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	50	1200	4978
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	85	2040	4979
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	97	2328	4980
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	87	2088	4981
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	74	1776	4982
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	69	1656	4983
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	82	1968	4984
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	99	2376	4985
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	67	1608	4986
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	92	2208	4987
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	97	2328	4988
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	61	1464	4989
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	74	1776	4990
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	68	1632	4991
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	93	2232	4992
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	58	1392	4993
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	81	1944	4994
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	58	1392	4995
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	54	1296	4996
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	100	2400	4997
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	97	2328	4998
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	79	1896	4999
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	68	1632	5000
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	80	1920	5001
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	89	2136	5002
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	57	1368	5003
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	79	1896	5004
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	73	1752	5005
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	58	1392	5006
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	79	1896	5007
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	69	1656	5008
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	87	2088	5009
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	83	1992	5010
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	58	1392	5011
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	68	1632	5012
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	89	2136	5013
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	69	1656	5014
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	52	1248	5015
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	95	2280	5016
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	69	1656	5017
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	94	2256	5018
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	80	1920	5019
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	61	1464	5020
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	86	2064	5021
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	55	1320	5022
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	79	1896	5023
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	67	1608	5024
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	97	2328	5025
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	90	2160	5026
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	60	1440	5027
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	80	1920	5028
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	63	1512	5029
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	90	2160	5030
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	85	2040	5031
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	66	1584	5032
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	82	1968	5033
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	62	1488	5034
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	64	1536	5035
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	5036
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	94	2256	5037
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	64	1536	5038
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	59	1416	5039
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	78	1872	5040
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	66	1584	5041
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	55	1320	5042
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	60	1440	5043
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	76	1824	5044
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	5045
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	68	1632	5046
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	83	1992	5047
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	95	2280	5048
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	66	1584	5049
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	5050
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	69	1656	5051
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	96	2304	5052
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	70	1680	5053
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	59	1416	5054
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	96	2304	5055
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	62	1488	5056
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	78	1872	5057
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	89	2136	5058
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	76	1824	5059
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	82	1968	5060
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	93	2232	5061
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	51	1224	5062
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	76	1824	5063
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	96	2304	5064
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	65	1560	5065
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	58	1392	5066
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	86	2064	5067
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	99	2376	5068
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	94	2256	5069
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	51	1224	5070
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	62	1488	5071
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	51	1224	5072
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	87	2088	5073
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	91	2184	5074
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	94	2256	5075
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	100	2400	5076
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	93	2232	5077
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	73	1752	5078
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	91	2184	5079
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	91	2184	5080
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	76	1824	5081
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	88	2112	5082
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	75	1800	5083
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	52	1248	5084
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	63	1512	5085
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	97	2328	5086
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	54	1296	5087
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	91	2184	5088
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	59	1416	5089
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	85	2040	5090
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	86	2064	5091
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	71	1704	5092
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	62	1488	5093
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	63	1512	5094
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	94	2256	5095
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	67	1608	5096
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	59	1416	5097
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	78	1872	5098
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	66	1584	5099
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	80	1920	5100
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	63	1512	5101
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	74	1776	5102
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	57	1368	5103
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	65	1560	5104
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	91	2184	5105
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	72	1728	5106
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	68	1632	5107
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	68	1632	5108
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	61	1464	5109
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	78	1872	5110
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	67	1608	5111
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	92	2208	5112
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	69	1656	5113
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	64	1536	5114
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	73	1752	5115
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	80	1920	5116
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	57	1368	5117
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	85	2040	5118
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	93	2232	5119
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	65	1560	5120
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	98	2352	5121
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	55	1320	5122
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	55	1320	5123
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	62	1488	5124
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	61	1464	5125
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	95	2280	5126
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	86	2064	5127
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	94	2256	5128
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	88	2112	5129
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	61	1464	5130
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	73	1752	5131
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	73	1752	5132
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	84	2016	5133
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	98	2352	5134
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	96	2304	5135
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	85	2040	5136
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	72	1728	5137
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	97	2328	5138
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	52	1248	5139
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	69	1656	5140
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	61	1464	5141
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	66	1584	5142
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	83	1992	5143
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	53	1272	5144
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	81	1944	5145
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	88	2112	5146
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	75	1800	5147
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	85	2040	5148
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	65	1560	5149
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	90	2160	5150
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	68	1632	5151
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	87	2088	5152
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	85	2040	5153
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	84	2016	5154
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	66	1584	5155
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	60	1440	5156
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	54	1296	5157
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	73	1752	5158
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	52	1248	5159
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	95	2280	5160
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	91	2184	5161
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	94	2256	5162
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	53	1272	5163
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	77	1848	5164
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	90	2160	5165
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	83	1992	5166
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	97	2328	5167
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	79	1896	5168
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	51	1224	5169
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	76	1824	5170
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	80	1920	5171
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	50	1200	5172
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	67	1608	5173
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	61	1464	5174
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	97	2328	5175
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	60	1440	5176
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	91	2184	5177
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	61	1464	5178
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	71	1704	5179
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	51	1224	5180
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	99	2376	5181
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	89	2136	5182
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	72	1728	5183
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	50	1200	5184
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	92	2208	5185
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	70	1680	5186
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	56	1344	5187
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	86	2064	5188
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	63	1512	5189
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	55	1320	5190
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	58	1392	5191
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	72	1728	5192
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	87	2088	5193
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	63	1512	5194
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	92	2208	5195
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	96	2304	5196
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	98	2352	5197
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	82	1968	5198
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	66	1584	5199
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	82	1968	5200
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	80	1920	5201
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	78	1872	5202
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	73	1752	5203
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	62	1488	5204
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	83	1992	5205
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	83	1992	5206
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	67	1608	5207
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	72	1728	5208
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	92	2208	5209
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	96	2304	5210
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	51	1224	5211
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	52	1248	5212
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	56	1344	5213
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	88	2112	5214
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	83	1992	5215
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	62	1488	5216
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	78	1872	5217
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	86	2064	5218
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	91	2184	5219
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	85	2040	5220
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	77	1848	5221
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	66	1584	5222
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	71	1704	5223
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	53	1272	5224
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	5225
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	100	2400	5226
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	60	1440	5227
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	92	2208	5228
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	61	1464	5229
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	82	1968	5230
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	94	2256	5231
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	89	2136	5232
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	74	1776	5233
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	60	1440	5234
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	79	1896	5235
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	86	2064	5236
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	70	1680	5237
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	96	2304	5238
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	89	2136	5239
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	94	2256	5240
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	82	1968	5241
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	83	1992	5242
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	81	1944	5243
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	65	1560	5244
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	99	2376	5245
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	99	2376	5246
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	98	2352	5247
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	99	2376	5248
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	71	1704	5249
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	75	1800	5250
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	90	2160	5251
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	63	1512	5252
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	56	1344	5253
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	57	1368	5254
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	5255
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	89	2136	5256
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	81	1944	5257
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	55	1320	5258
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	68	1632	5259
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	89	2136	5260
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	100	2400	5261
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	92	2208	5262
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	70	1680	5263
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	89	2136	5264
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	75	1800	5265
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	74	1776	5266
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	72	1728	5267
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	67	1608	5268
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	68	1632	5269
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	82	1968	5270
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	64	1536	5271
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	50	1200	5272
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	85	2040	5273
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	67	1608	5274
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	95	2280	5275
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	78	1872	5276
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	83	1992	5277
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	55	1320	5278
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	83	1992	5279
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	98	2352	5280
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	79	1896	5281
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	71	1704	5282
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	69	1656	5283
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	62	1488	5284
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	86	2064	5285
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	65	1560	5286
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	97	2328	5287
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	61	1464	5288
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	93	2232	5289
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	64	1536	5290
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	98	2352	5291
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	56	1344	5292
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	70	1680	5293
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	75	1800	5294
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	5295
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	87	2088	5296
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	56	1344	5297
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	89	2136	5298
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	53	1272	5299
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	94	2256	5300
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	67	1608	5301
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	80	1920	5302
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	82	1968	5303
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	90	2160	5304
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	60	1440	5305
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	66	1584	5306
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	50	1200	5307
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	84	2016	5308
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	70	1680	5309
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	80	1920	5310
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	75	1800	5311
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	76	1824	5312
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	92	2208	5313
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	89	2136	5314
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	81	1944	5315
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	54	1296	5316
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	84	2016	5317
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	85	2040	5318
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	73	1752	5319
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	97	2328	5320
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	85	2040	5321
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	60	1440	5322
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	95	2280	5323
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	53	1272	5324
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	53	1272	5325
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	86	2064	5326
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	74	1776	5327
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	99	2376	5328
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	79	1896	5329
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	81	1944	5330
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	80	1920	5331
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	73	1752	5332
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	73	1752	5333
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	62	1488	5334
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	80	1920	5335
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	65	1560	5336
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	83	1992	5337
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	99	2376	5338
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	92	2208	5339
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	88	2112	5340
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	93	2232	5341
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	66	1584	5342
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	93	2232	5343
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	66	1584	5344
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	80	1920	5345
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	94	2256	5346
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	66	1584	5347
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	98	2352	5348
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	57	1368	5349
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	76	1824	5350
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	92	2208	5351
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	91	2184	5352
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	62	1488	5353
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	77	1848	5354
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	100	2400	5355
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	5356
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	100	2400	5357
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	73	1752	5358
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	53	1272	5359
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	58	1392	5360
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	97	2328	5361
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	85	2040	5362
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	63	1512	5363
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	85	2040	5364
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	100	2400	5365
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	99	2376	5366
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	52	1248	5367
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	71	1704	5368
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	96	2304	5369
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	72	1728	5370
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	83	1992	5371
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	94	2256	5372
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	53	1272	5373
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	77	1848	5374
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	71	1704	5375
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	71	1704	5376
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	66	1584	5377
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	58	1392	5378
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	73	1752	5379
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	85	2040	5380
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	50	1200	5381
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	77	1848	5382
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	84	2016	5383
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	53	1272	5384
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	84	2016	5385
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	100	2400	5386
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	77	1848	5387
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	67	1608	5388
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	64	1536	5389
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	91	2184	5390
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	76	1824	5391
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	83	1992	5392
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	68	1632	5393
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	59	1416	5394
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	5395
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	96	2304	5396
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	59	1416	5397
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	59	1416	5398
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	73	1752	5399
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	64	1536	5400
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	53	1272	5401
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	51	1224	5402
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	87	2088	5403
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	99	2376	5404
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	66	1584	5405
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	65	1560	5406
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	69	1656	5407
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	50	1200	5408
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	85	2040	5409
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	67	1608	5410
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	91	2184	5411
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	73	1752	5412
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	92	2208	5413
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	76	1824	5414
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	68	1632	5415
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	94	2256	5416
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	93	2232	5417
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	85	2040	5418
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	64	1536	5419
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	73	1752	5420
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	100	2400	5421
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	76	1824	5422
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	83	1992	5423
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	98	2352	5424
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	79	1896	5425
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	59	1416	5426
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	97	2328	5427
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	96	2304	5428
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	74	1776	5429
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	61	1464	5430
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	52	1248	5431
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	73	1752	5432
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	70	1680	5433
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	89	2136	5434
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	56	1344	5435
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	99	2376	5436
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	73	1752	5437
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	84	2016	5438
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	68	1632	5439
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	99	2376	5440
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	75	1800	5441
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	51	1224	5442
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	62	1488	5443
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	95	2280	5444
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	5445
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	60	1440	5446
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	99	2376	5447
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	77	1848	5448
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	97	2328	5449
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	50	1200	5450
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	90	2160	5451
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	79	1896	5452
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	53	1272	5453
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	81	1944	5454
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	77	1848	5455
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	72	1728	5456
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	58	1392	5457
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	59	1416	5458
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	81	1944	5459
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	71	1704	5460
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	62	1488	5461
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	97	2328	5462
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	99	2376	5463
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	60	1440	5464
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	96	2304	5465
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	52	1248	5466
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	66	1584	5467
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	52	1248	5468
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	79	1896	5469
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	60	1440	5470
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	88	2112	5471
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	79	1896	5472
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	83	1992	5473
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	64	1536	5474
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	85	2040	5475
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	72	1728	5476
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	66	1584	5477
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	51	1224	5478
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	97	2328	5479
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	82	1968	5480
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	59	1416	5481
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	98	2352	5482
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	72	1728	5483
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	61	1464	5484
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	94	2256	5485
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	64	1536	5486
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	71	1704	5487
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	69	1656	5488
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	92	2208	5489
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	78	1872	5490
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	54	1296	5491
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	54	1296	5492
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	60	1440	5493
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	86	2064	5494
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	73	1752	5495
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	51	1224	5496
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	88	2112	5497
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	63	1512	5498
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	90	2160	5499
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	70	1680	5500
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	73	1752	5501
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	70	1680	5502
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	69	1656	5503
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	92	2208	5504
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	5505
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	92	2208	5506
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	77	1848	5507
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	84	2016	5508
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	58	1392	5509
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	100	2400	5510
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	86	2064	5511
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	60	1440	5512
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	87	2088	5513
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	72	1728	5514
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	79	1896	5515
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	100	2400	5516
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	55	1320	5517
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	85	2040	5518
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	84	2016	5519
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	85	2040	5520
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	56	1344	5521
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	83	1992	5522
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	65	1560	5523
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	57	1368	5524
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	84	2016	5525
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	81	1944	5526
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	72	1728	5527
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	69	1656	5528
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	59	1416	5529
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	83	1992	5530
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	60	1440	5531
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	76	1824	5532
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	78	1872	5533
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	52	1248	5534
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	66	1584	5535
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	66	1584	5536
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	56	1344	5537
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	88	2112	5538
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	89	2136	5539
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	96	2304	5540
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	56	1344	5541
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	81	1944	5542
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	98	2352	5543
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	97	2328	5544
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	66	1584	5545
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	97	2328	5546
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	65	1560	5547
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	78	1872	5548
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	63	1512	5549
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	5550
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	99	2376	5551
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	65	1560	5552
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	94	2256	5553
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	73	1752	5554
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	96	2304	5555
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	65	1560	5556
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	81	1944	5557
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	89	2136	5558
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	97	2328	5559
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	80	1920	5560
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	75	1800	5561
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	80	1920	5562
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	93	2232	5563
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	76	1824	5564
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	98	2352	5565
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	53	1272	5566
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	60	1440	5567
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	54	1296	5568
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	65	1560	5569
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	80	1920	5570
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	53	1272	5571
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	87	2088	5572
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	71	1704	5573
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	64	1536	5574
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	5575
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	96	2304	5576
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	68	1632	5577
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	54	1296	5578
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	59	1416	5579
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	81	1944	5580
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	60	1440	5581
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	86	2064	5582
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	65	1560	5583
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	90	2160	5584
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	80	1920	5585
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	77	1848	5586
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	66	1584	5587
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	86	2064	5588
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	87	2088	5589
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	73	1752	5590
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	90	2160	5591
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	81	1944	5592
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	83	1992	5593
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	61	1464	5594
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	69	1656	5595
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	55	1320	5596
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	60	1440	5597
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	76	1824	5598
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	86	2064	5599
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	67	1608	5600
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	62	1488	5601
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	79	1896	5602
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	81	1944	5603
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	55	1320	5604
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	5605
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	92	2208	5606
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	75	1800	5607
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	60	1440	5608
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	78	1872	5609
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	80	1920	5610
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	90	2160	5611
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	96	2304	5612
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	51	1224	5613
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	89	2136	5614
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	67	1608	5615
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	70	1680	5616
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	96	2304	5617
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	57	1368	5618
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	86	2064	5619
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	71	1704	5620
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	94	2256	5621
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	77	1848	5622
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	52	1248	5623
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	91	2184	5624
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	98	2352	5625
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	78	1872	5626
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	92	2208	5627
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	50	1200	5628
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	68	1632	5629
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	60	1440	5630
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	75	1800	5631
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	73	1752	5632
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	66	1584	5633
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	80	1920	5634
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	99	2376	5635
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	95	2280	5636
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	70	1680	5637
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	86	2064	5638
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	55	1320	5639
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	83	1992	5640
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	84	2016	5641
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	98	2352	5642
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	99	2376	5643
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	51	1224	5644
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	93	2232	5645
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	100	2400	5646
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	98	2352	5647
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	92	2208	5648
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	80	1920	5649
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	51	1224	5650
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	100	2400	5651
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	69	1656	5652
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	70	1680	5653
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	82	1968	5654
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	90	2160	5655
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	5656
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	56	1344	5657
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	52	1248	5658
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	63	1512	5659
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	71	1704	5660
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	99	2376	5661
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	68	1632	5662
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	69	1656	5663
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	51	1224	5664
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	81	1944	5665
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	93	2232	5666
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	89	2136	5667
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	81	1944	5668
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	70	1680	5669
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	60	1440	5670
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	63	1512	5671
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	100	2400	5672
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	63	1512	5673
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	82	1968	5674
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	90	2160	5675
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	85	2040	5676
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	53	1272	5677
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	83	1992	5678
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	70	1680	5679
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	91	2184	5680
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	87	2088	5681
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	62	1488	5682
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	66	1584	5683
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	56	1344	5684
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	94	2256	5685
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	82	1968	5686
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	63	1512	5687
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	61	1464	5688
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	96	2304	5689
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	98	2352	5690
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	97	2328	5691
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	79	1896	5692
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	96	2304	5693
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	61	1464	5694
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	51	1224	5695
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	71	1704	5696
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	87	2088	5697
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	95	2280	5698
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	59	1416	5699
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	88	2112	5700
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	78	1872	5701
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	59	1416	5702
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	63	1512	5703
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	55	1320	5704
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	64	1536	5705
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	80	1920	5706
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	56	1344	5707
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	74	1776	5708
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	52	1248	5709
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	88	2112	5710
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	89	2136	5711
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	54	1296	5712
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	53	1272	5713
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	69	1656	5714
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	99	2376	5715
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	66	1584	5716
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	86	2064	5717
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	86	2064	5718
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	100	2400	5719
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	95	2280	5720
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	60	1440	5721
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	55	1320	5722
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	85	2040	5723
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	50	1200	5724
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	73	1752	5725
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	52	1248	5726
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	81	1944	5727
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	51	1224	5728
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	96	2304	5729
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	100	2400	5730
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	84	2016	5731
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	65	1560	5732
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	62	1488	5733
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	71	1704	5734
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	54	1296	5735
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	69	1656	5736
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	85	2040	5737
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	99	2376	5738
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	53	1272	5739
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	82	1968	5740
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	61	1464	5741
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	56	1344	5742
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	83	1992	5743
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	86	2064	5744
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	85	2040	5745
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	55	1320	5746
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	59	1416	5747
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	56	1344	5748
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	70	1680	5749
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	93	2232	5750
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	99	2376	5751
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	54	1296	5752
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	80	1920	5753
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	58	1392	5754
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	95	2280	5755
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	72	1728	5756
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	80	1920	5757
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	90	2160	5758
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	81	1944	5759
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	58	1392	5760
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	79	1896	5761
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	72	1728	5762
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	98	2352	5763
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	96	2304	5764
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	81	1944	5765
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	100	2400	5766
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	82	1968	5767
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	80	1920	5768
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	96	2304	5769
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	5770
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	75	1800	5771
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	99	2376	5772
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	87	2088	5773
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	82	1968	5774
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	87	2088	5775
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	82	1968	5776
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	55	1320	5777
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	84	2016	5778
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	67	1608	5779
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	96	2304	5780
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	98	2352	5781
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	81	1944	5782
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	50	1200	5783
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	80	1920	5784
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	51	1224	5785
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	89	2136	5786
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	87	2088	5787
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	72	1728	5788
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	100	2400	5789
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	62	1488	5790
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	89	2136	5791
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	83	1992	5792
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	77	1848	5793
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	99	2376	5794
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	62	1488	5795
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	92	2208	5796
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	88	2112	5797
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	57	1368	5798
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	98	2352	5799
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	65	1560	5800
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	94	2256	5801
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	59	1416	5802
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	77	1848	5803
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	69	1656	5804
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	83	1992	5805
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	81	1944	5806
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	73	1752	5807
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	73	1752	5808
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	57	1368	5809
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	58	1392	5810
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	68	1632	5811
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	66	1584	5812
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	57	1368	5813
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	71	1704	5814
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	5815
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	74	1776	5816
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	56	1344	5817
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	64	1536	5818
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	63	1512	5819
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	74	1776	5820
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	63	1512	5821
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	62	1488	5822
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	76	1824	5823
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	99	2376	5824
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	78	1872	5825
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	79	1896	5826
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	81	1944	5827
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	68	1632	5828
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	69	1656	5829
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	75	1800	5830
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	74	1776	5831
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	65	1560	5832
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	54	1296	5833
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	69	1656	5834
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	92	2208	5835
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	61	1464	5836
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	74	1776	5837
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	97	2328	5838
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	64	1536	5839
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	93	2232	5840
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	50	1200	5841
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	84	2016	5842
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	94	2256	5843
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	87	2088	5844
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	97	2328	5845
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	95	2280	5846
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	94	2256	5847
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	81	1944	5848
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	66	1584	5849
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	65	1560	5850
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	62	1488	5851
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	75	1800	5852
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	61	1464	5853
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	97	2328	5854
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	60	1440	5855
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	97	2328	5856
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	89	2136	5857
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	84	2016	5858
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	96	2304	5859
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	99	2376	5860
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	93	2232	5861
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	54	1296	5862
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	96	2304	5863
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	51	1224	5864
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	100	2400	5865
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	90	2160	5866
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	89	2136	5867
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	51	1224	5868
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	88	2112	5869
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	51	1224	5870
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	89	2136	5871
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	100	2400	5872
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	98	2352	5873
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	86	2064	5874
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	74	1776	5875
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	5876
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	50	1200	5877
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	85	2040	5878
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	76	1824	5879
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	86	2064	5880
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	73	1752	5881
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	76	1824	5882
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	54	1296	5883
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	92	2208	5884
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	93	2232	5885
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	60	1440	5886
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	61	1464	5887
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	87	2088	5888
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	56	1344	5889
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	61	1464	5890
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	67	1608	5891
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	76	1824	5892
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	82	1968	5893
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	61	1464	5894
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	67	1608	5895
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	5896
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	95	2280	5897
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	59	1416	5898
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	88	2112	5899
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	56	1344	5900
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	68	1632	5901
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	64	1536	5902
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	62	1488	5903
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	96	2304	5904
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	63	1512	5905
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	55	1320	5906
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	94	2256	5907
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	70	1680	5908
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	70	1680	5909
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	79	1896	5910
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	56	1344	5911
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	81	1944	5912
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	100	2400	5913
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	79	1896	5914
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	52	1248	5915
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	54	1296	5916
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	72	1728	5917
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	74	1776	5918
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	79	1896	5919
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	65	1560	5920
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	61	1464	5921
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	68	1632	5922
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	86	2064	5923
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	76	1824	5924
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	57	1368	5925
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	94	2256	5926
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	72	1728	5927
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	66	1584	5928
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	99	2376	5929
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	5930
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	77	1848	5931
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	50	1200	5932
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	99	2376	5933
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	90	2160	5934
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	59	1416	5935
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	70	1680	5936
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	82	1968	5937
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	76	1824	5938
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	58	1392	5939
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	54	1296	5940
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	66	1584	5941
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	60	1440	5942
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	91	2184	5943
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	92	2208	5944
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	83	1992	5945
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	90	2160	5946
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	66	1584	5947
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	80	1920	5948
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	62	1488	5949
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	96	2304	5950
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	73	1752	5951
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	98	2352	5952
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	54	1296	5953
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	93	2232	5954
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	83	1992	5955
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	51	1224	5956
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	73	1752	5957
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	70	1680	5958
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	62	1488	5959
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	83	1992	5960
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	63	1512	5961
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	85	2040	5962
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	98	2352	5963
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	66	1584	5964
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	65	1560	5965
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	50	1200	5966
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	86	2064	5967
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	78	1872	5968
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	82	1968	5969
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	86	2064	5970
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	76	1824	5971
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	91	2184	5972
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	55	1320	5973
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	55	1320	5974
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	71	1704	5975
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	5976
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	90	2160	5977
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	92	2208	5978
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	58	1392	5979
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	54	1296	5980
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	68	1632	5981
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	62	1488	5982
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	80	1920	5983
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	62	1488	5984
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	92	2208	5985
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	58	1392	5986
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	99	2376	5987
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	96	2304	5988
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	67	1608	5989
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	66	1584	5990
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	55	1320	5991
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	50	1200	5992
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	87	2088	5993
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	68	1632	5994
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	89	2136	5995
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	75	1800	5996
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	66	1584	5997
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	56	1344	5998
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	86	2064	5999
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	57	1368	6000
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	67	1608	6001
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	60	1440	6002
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	93	2232	6003
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	98	2352	6004
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	54	1296	6005
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	59	1416	6006
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	78	1872	6007
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	88	2112	6008
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	89	2136	6009
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	96	2304	6010
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	72	1728	6011
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	99	2376	6012
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	75	1800	6013
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	54	1296	6014
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	59	1416	6015
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	6016
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	54	1296	6017
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	94	2256	6018
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	60	1440	6019
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	95	2280	6020
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	50	1200	6021
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	72	1728	6022
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	82	1968	6023
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	75	1800	6024
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	69	1656	6025
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	72	1728	6026
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	58	1392	6027
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	75	1800	6028
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	96	2304	6029
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	81	1944	6030
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	91	2184	6031
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	92	2208	6032
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	68	1632	6033
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	89	2136	6034
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	92	2208	6035
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	89	2136	6036
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	75	1800	6037
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	58	1392	6038
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	72	1728	6039
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	66	1584	6040
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	88	2112	6041
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	78	1872	6042
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	56	1344	6043
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	91	2184	6044
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	98	2352	6045
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	91	2184	6046
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	88	2112	6047
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	71	1704	6048
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	75	1800	6049
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	77	1848	6050
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	63	1512	6051
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	88	2112	6052
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	74	1776	6053
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	70	1680	6054
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	61	1464	6055
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	73	1752	6056
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	77	1848	6057
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	89	2136	6058
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	51	1224	6059
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	61	1464	6060
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	75	1800	6061
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	58	1392	6062
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	86	2064	6063
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	54	1296	6064
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	72	1728	6065
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	62	1488	6066
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	64	1536	6067
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	53	1272	6068
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	76	1824	6069
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	72	1728	6070
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	52	1248	6071
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	97	2328	6072
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	96	2304	6073
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	77	1848	6074
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	93	2232	6075
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	84	2016	6076
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	89	2136	6077
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	82	1968	6078
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	87	2088	6079
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	65	1560	6080
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	98	2352	6081
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	62	1488	6082
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	98	2352	6083
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	71	1704	6084
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	65	1560	6085
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	71	1704	6086
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	78	1872	6087
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	59	1416	6088
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	76	1824	6089
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	6090
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	86	2064	6091
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	56	1344	6092
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	70	1680	6093
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	56	1344	6094
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	64	1536	6095
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	66	1584	6096
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	99	2376	6097
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	59	1416	6098
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	89	2136	6099
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	85	2040	6100
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	84	2016	6101
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	67	1608	6102
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	100	2400	6103
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	70	1680	6104
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	69	1656	6105
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	64	1536	6106
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	89	2136	6107
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	64	1536	6108
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	76	1824	6109
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	50	1200	6110
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	99	2376	6111
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	60	1440	6112
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	75	1800	6113
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	94	2256	6114
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	75	1800	6115
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	55	1320	6116
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	77	1848	6117
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	60	1440	6118
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	63	1512	6119
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	69	1656	6120
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	87	2088	6121
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	100	2400	6122
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	75	1800	6123
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	59	1416	6124
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	6125
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	73	1752	6126
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	51	1224	6127
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	61	1464	6128
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	72	1728	6129
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	96	2304	6130
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	57	1368	6131
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	90	2160	6132
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	85	2040	6133
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	54	1296	6134
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	87	2088	6135
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	94	2256	6136
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	88	2112	6137
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	73	1752	6138
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	81	1944	6139
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	56	1344	6140
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	55	1320	6141
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	99	2376	6142
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	51	1224	6143
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	61	1464	6144
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	75	1800	6145
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	81	1944	6146
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	51	1224	6147
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	93	2232	6148
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	77	1848	6149
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	73	1752	6150
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	59	1416	6151
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	87	2088	6152
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	61	1464	6153
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	76	1824	6154
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	96	2304	6155
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	6156
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	63	1512	6157
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	95	2280	6158
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	64	1536	6159
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	60	1440	6160
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	85	2040	6161
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	69	1656	6162
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	63	1512	6163
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	75	1800	6164
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	61	1464	6165
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	62	1488	6166
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	81	1944	6167
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	80	1920	6168
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	80	1920	6169
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	75	1800	6170
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	84	2016	6171
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	65	1560	6172
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	89	2136	6173
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	63	1512	6174
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	72	1728	6175
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	88	2112	6176
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	77	1848	6177
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	97	2328	6178
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	95	2280	6179
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	58	1392	6180
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	98	2352	6181
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	66	1584	6182
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	52	1248	6183
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	59	1416	6184
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	93	2232	6185
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	96	2304	6186
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	90	2160	6187
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	74	1776	6188
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	91	2184	6189
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	92	2208	6190
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	77	1848	6191
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	74	1776	6192
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	74	1776	6193
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	60	1440	6194
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	87	2088	6195
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	77	1848	6196
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	89	2136	6197
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	94	2256	6198
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	87	2088	6199
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	80	1920	6200
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	58	1392	6201
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	89	2136	6202
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	62	1488	6203
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	57	1368	6204
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	83	1992	6205
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	59	1416	6206
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	80	1920	6207
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	88	2112	6208
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	79	1896	6209
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	90	2160	6210
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	52	1248	6211
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	64	1536	6212
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	77	1848	6213
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	90	2160	6214
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	51	1224	6215
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	94	2256	6216
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	91	2184	6217
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	70	1680	6218
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	92	2208	6219
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	58	1392	6220
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	78	1872	6221
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	51	1224	6222
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	88	2112	6223
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	98	2352	6224
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	85	2040	6225
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	57	1368	6226
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	81	1944	6227
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	93	2232	6228
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	59	1416	6229
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	58	1392	6230
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	66	1584	6231
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	89	2136	6232
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	65	1560	6233
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	71	1704	6234
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	73	1752	6235
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	61	1464	6236
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	59	1416	6237
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	79	1896	6238
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	100	2400	6239
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	53	1272	6240
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	74	1776	6241
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	68	1632	6242
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	74	1776	6243
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	50	1200	6244
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	93	2232	6245
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	53	1272	6246
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	69	1656	6247
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	56	1344	6248
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	100	2400	6249
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	6250
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	85	2040	6251
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	61	1464	6252
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	88	2112	6253
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	92	2208	6254
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	93	2232	6255
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	98	2352	6256
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	61	1464	6257
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	56	1344	6258
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	70	1680	6259
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	73	1752	6260
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	68	1632	6261
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	100	2400	6262
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	94	2256	6263
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	62	1488	6264
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	90	2160	6265
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	93	2232	6266
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	61	1464	6267
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	59	1416	6268
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	59	1416	6269
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	95	2280	6270
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	73	1752	6271
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	65	1560	6272
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	76	1824	6273
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	85	2040	6274
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	91	2184	6275
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	82	1968	6276
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	54	1296	6277
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	58	1392	6278
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	72	1728	6279
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	66	1584	6280
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	54	1296	6281
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	69	1656	6282
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	96	2304	6283
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	62	1488	6284
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	98	2352	6285
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	88	2112	6286
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	62	1488	6287
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	88	2112	6288
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	99	2376	6289
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	72	1728	6290
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	78	1872	6291
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	95	2280	6292
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	54	1296	6293
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	76	1824	6294
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	79	1896	6295
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	65	1560	6296
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	87	2088	6297
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	98	2352	6298
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	51	1224	6299
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	62	1488	6300
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	61	1464	6301
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	68	1632	6302
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	96	2304	6303
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	97	2328	6304
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	90	2160	6305
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	64	1536	6306
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	81	1944	6307
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	55	1320	6308
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	75	1800	6309
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	6310
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	77	1848	6311
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	70	1680	6312
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	50	1200	6313
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	53	1272	6314
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	80	1920	6315
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	92	2208	6316
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	72	1728	6317
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	93	2232	6318
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	87	2088	6319
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	59	1416	6320
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	71	1704	6321
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	64	1536	6322
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	65	1560	6323
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	60	1440	6324
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	64	1536	6325
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	91	2184	6326
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	87	2088	6327
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	80	1920	6328
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	87	2088	6329
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	95	2280	6330
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	64	1536	6331
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	79	1896	6332
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	51	1224	6333
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	65	1560	6334
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	60	1440	6335
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	75	1800	6336
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	66	1584	6337
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	51	1224	6338
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	72	1728	6339
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	78	1872	6340
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	78	1872	6341
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	67	1608	6342
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	65	1560	6343
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	93	2232	6344
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	88	2112	6345
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	81	1944	6346
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	71	1704	6347
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	96	2304	6348
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	89	2136	6349
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	77	1848	6350
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	74	1776	6351
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	95	2280	6352
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	73	1752	6353
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	98	2352	6354
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	68	1632	6355
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	96	2304	6356
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	64	1536	6357
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	83	1992	6358
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	87	2088	6359
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	57	1368	6360
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	82	1968	6361
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	91	2184	6362
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	75	1800	6363
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	77	1848	6364
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	50	1200	6365
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	89	2136	6366
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	86	2064	6367
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	53	1272	6368
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	97	2328	6369
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	68	1632	6370
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	86	2064	6371
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	70	1680	6372
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	56	1344	6373
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	88	2112	6374
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	87	2088	6375
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	99	2376	6376
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	85	2040	6377
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	99	2376	6378
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	97	2328	6379
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	83	1992	6380
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	62	1488	6381
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	59	1416	6382
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	81	1944	6383
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	60	1440	6384
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	58	1392	6385
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	68	1632	6386
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	52	1248	6387
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	62	1488	6388
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	61	1464	6389
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	80	1920	6390
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	80	1920	6391
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	71	1704	6392
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	93	2232	6393
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	90	2160	6394
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	73	1752	6395
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	76	1824	6396
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	87	2088	6397
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	72	1728	6398
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	89	2136	6399
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	85	2040	6400
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	76	1824	6401
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	54	1296	6402
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	91	2184	6403
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	75	1800	6404
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	51	1224	6405
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	66	1584	6406
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	53	1272	6407
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	83	1992	6408
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	55	1320	6409
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	54	1296	6410
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	86	2064	6411
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	66	1584	6412
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	68	1632	6413
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	63	1512	6414
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	60	1440	6415
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	59	1416	6416
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	76	1824	6417
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	78	1872	6418
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	54	1296	6419
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	83	1992	6420
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	99	2376	6421
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	51	1224	6422
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	93	2232	6423
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	63	1512	6424
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	88	2112	6425
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	100	2400	6426
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	50	1200	6427
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	75	1800	6428
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	63	1512	6429
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	60	1440	6430
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	82	1968	6431
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	94	2256	6432
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	92	2208	6433
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	69	1656	6434
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	99	2376	6435
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	67	1608	6436
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	64	1536	6437
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	99	2376	6438
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	87	2088	6439
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	69	1656	6440
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	97	2328	6441
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	53	1272	6442
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	71	1704	6443
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	74	1776	6444
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	65	1560	6445
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	50	1200	6446
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	65	1560	6447
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	99	2376	6448
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	50	1200	6449
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	83	1992	6450
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	59	1416	6451
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	70	1680	6452
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	80	1920	6453
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	79	1896	6454
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	78	1872	6455
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	100	2400	6456
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	68	1632	6457
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	52	1248	6458
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	100	2400	6459
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	81	1944	6460
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	81	1944	6461
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	89	2136	6462
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	70	1680	6463
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	55	1320	6464
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	58	1392	6465
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	98	2352	6466
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	98	2352	6467
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	80	1920	6468
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	62	1488	6469
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	75	1800	6470
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	94	2256	6471
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	81	1944	6472
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	83	1992	6473
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	90	2160	6474
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	89	2136	6475
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	90	2160	6476
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	60	1440	6477
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	98	2352	6478
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	54	1296	6479
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	56	1344	6480
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	73	1752	6481
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	94	2256	6482
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	82	1968	6483
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	73	1752	6484
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	64	1536	6485
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	58	1392	6486
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	83	1992	6487
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	86	2064	6488
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	76	1824	6489
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	51	1224	6490
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	94	2256	6491
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	65	1560	6492
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	94	2256	6493
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	77	1848	6494
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	6495
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	66	1584	6496
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	57	1368	6497
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	93	2232	6498
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	77	1848	6499
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	83	1992	6500
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	67	1608	6501
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	88	2112	6502
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	50	1200	6503
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	99	2376	6504
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	75	1800	6505
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	92	2208	6506
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	100	2400	6507
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	99	2376	6508
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	68	1632	6509
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	95	2280	6510
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	89	2136	6511
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	51	1224	6512
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	63	1512	6513
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	80	1920	6514
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	6515
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	96	2304	6516
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	52	1248	6517
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	96	2304	6518
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	82	1968	6519
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	56	1344	6520
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	52	1248	6521
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	79	1896	6522
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	90	2160	6523
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	88	2112	6524
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	77	1848	6525
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	55	1320	6526
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	52	1248	6527
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	57	1368	6528
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	71	1704	6529
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	78	1872	6530
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	90	2160	6531
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	80	1920	6532
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	70	1680	6533
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	71	1704	6534
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	54	1296	6535
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	61	1464	6536
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	87	2088	6537
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	96	2304	6538
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	66	1584	6539
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	100	2400	6540
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	87	2088	6541
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	70	1680	6542
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	79	1896	6543
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	67	1608	6544
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	70	1680	6545
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	65	1560	6546
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	77	1848	6547
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	63	1512	6548
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	58	1392	6549
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	64	1536	6550
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	74	1776	6551
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	75	1800	6552
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	58	1392	6553
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	70	1680	6554
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	61	1464	6555
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	69	1656	6556
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	89	2136	6557
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	87	2088	6558
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	95	2280	6559
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	56	1344	6560
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	93	2232	6561
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	63	1512	6562
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	59	1416	6563
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	78	1872	6564
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	91	2184	6565
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	62	1488	6566
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	62	1488	6567
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	59	1416	6568
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	82	1968	6569
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	82	1968	6570
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	56	1344	6571
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	62	1488	6572
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	71	1704	6573
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	59	1416	6574
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	80	1920	6575
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	70	1680	6576
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	97	2328	6577
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	92	2208	6578
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	76	1824	6579
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	88	2112	6580
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	63	1512	6581
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	52	1248	6582
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	82	1968	6583
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	99	2376	6584
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	66	1584	6585
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	52	1248	6586
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	73	1752	6587
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	90	2160	6588
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	92	2208	6589
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	100	2400	6590
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	77	1848	6591
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	81	1944	6592
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	78	1872	6593
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	78	1872	6594
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	83	1992	6595
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	94	2256	6596
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	52	1248	6597
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	70	1680	6598
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	76	1824	6599
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	55	1320	6600
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	90	2160	6601
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	99	2376	6602
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	78	1872	6603
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	97	2328	6604
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	82	1968	6605
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	68	1632	6606
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	92	2208	6607
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	69	1656	6608
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	55	1320	6609
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	91	2184	6610
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	82	1968	6611
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	89	2136	6612
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	96	2304	6613
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	69	1656	6614
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	54	1296	6615
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	66	1584	6616
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	61	1464	6617
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	68	1632	6618
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	52	1248	6619
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	87	2088	6620
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	77	1848	6621
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	98	2352	6622
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	61	1464	6623
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	88	2112	6624
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	52	1248	6625
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	81	1944	6626
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	52	1248	6627
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	86	2064	6628
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	61	1464	6629
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	84	2016	6630
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	98	2352	6631
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	80	1920	6632
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	91	2184	6633
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	79	1896	6634
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	65	1560	6635
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	55	1320	6636
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	63	1512	6637
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	76	1824	6638
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	64	1536	6639
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	90	2160	6640
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	80	1920	6641
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	79	1896	6642
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	79	1896	6643
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	54	1296	6644
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	89	2136	6645
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	80	1920	6646
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	81	1944	6647
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	50	1200	6648
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	90	2160	6649
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	92	2208	6650
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	53	1272	6651
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	66	1584	6652
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	54	1296	6653
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	97	2328	6654
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	76	1824	6655
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	80	1920	6656
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	64	1536	6657
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	99	2376	6658
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	67	1608	6659
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	57	1368	6660
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	74	1776	6661
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	87	2088	6662
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	72	1728	6663
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	59	1416	6664
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	67	1608	6665
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	76	1824	6666
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	66	1584	6667
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	82	1968	6668
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	67	1608	6669
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	58	1392	6670
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	89	2136	6671
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	80	1920	6672
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	77	1848	6673
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	50	1200	6674
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	94	2256	6675
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	70	1680	6676
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	99	2376	6677
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	56	1344	6678
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	77	1848	6679
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	86	2064	6680
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	100	2400	6681
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	64	1536	6682
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	67	1608	6683
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	89	2136	6684
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	96	2304	6685
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	64	1536	6686
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	90	2160	6687
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	63	1512	6688
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	67	1608	6689
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	78	1872	6690
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	65	1560	6691
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	93	2232	6692
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	78	1872	6693
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	95	2280	6694
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	67	1608	6695
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	71	1704	6696
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	68	1632	6697
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	94	2256	6698
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	76	1824	6699
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	60	1440	6700
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	56	1344	6701
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	54	1296	6702
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	85	2040	6703
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	62	1488	6704
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	6705
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	89	2136	6706
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	80	1920	6707
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	63	1512	6708
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	81	1944	6709
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	92	2208	6710
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	92	2208	6711
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	80	1920	6712
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	83	1992	6713
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	99	2376	6714
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	62	1488	6715
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	58	1392	6716
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	70	1680	6717
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	100	2400	6718
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	100	2400	6719
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	67	1608	6720
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	85	2040	6721
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	78	1872	6722
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	58	1392	6723
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	77	1848	6724
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	81	1944	6725
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	74	1776	6726
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	69	1656	6727
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	61	1464	6728
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	76	1824	6729
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	73	1752	6730
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	88	2112	6731
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	98	2352	6732
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	79	1896	6733
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	80	1920	6734
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	94	2256	6735
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	78	1872	6736
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	61	1464	6737
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	82	1968	6738
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	75	1800	6739
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	77	1848	6740
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	91	2184	6741
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	83	1992	6742
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	56	1344	6743
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	57	1368	6744
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	55	1320	6745
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	73	1752	6746
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	82	1968	6747
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	82	1968	6748
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	55	1320	6749
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	67	1608	6750
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	68	1632	6751
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	80	1920	6752
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	50	1200	6753
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	88	2112	6754
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	79	1896	6755
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	54	1296	6756
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	66	1584	6757
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	60	1440	6758
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	88	2112	6759
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	75	1800	6760
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	88	2112	6761
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	90	2160	6762
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	98	2352	6763
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	52	1248	6764
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	60	1440	6765
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	54	1296	6766
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	94	2256	6767
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	63	1512	6768
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	98	2352	6769
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	70	1680	6770
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	69	1656	6771
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	83	1992	6772
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	82	1968	6773
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	91	2184	6774
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	53	1272	6775
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	65	1560	6776
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	77	1848	6777
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	50	1200	6778
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	65	1560	6779
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	75	1800	6780
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	97	2328	6781
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	63	1512	6782
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	81	1944	6783
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	67	1608	6784
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	87	2088	6785
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	80	1920	6786
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	50	1200	6787
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	50	1200	6788
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	89	2136	6789
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	52	1248	6790
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	65	1560	6791
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	89	2136	6792
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	82	1968	6793
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	56	1344	6794
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	83	1992	6795
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	94	2256	6796
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	79	1896	6797
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	61	1464	6798
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	73	1752	6799
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	59	1416	6800
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	97	2328	6801
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	63	1512	6802
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	93	2232	6803
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	61	1464	6804
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	95	2280	6805
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	73	1752	6806
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	93	2232	6807
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	87	2088	6808
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	69	1656	6809
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	54	1296	6810
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	54	1296	6811
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	69	1656	6812
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	68	1632	6813
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	70	1680	6814
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	52	1248	6815
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	84	2016	6816
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	70	1680	6817
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	61	1464	6818
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	64	1536	6819
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	58	1392	6820
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	70	1680	6821
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	70	1680	6822
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	60	1440	6823
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	52	1248	6824
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	75	1800	6825
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	62	1488	6826
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	60	1440	6827
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	80	1920	6828
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	69	1656	6829
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	87	2088	6830
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	94	2256	6831
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	54	1296	6832
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	64	1536	6833
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	70	1680	6834
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	55	1320	6835
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	62	1488	6836
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	69	1656	6837
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	57	1368	6838
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	93	2232	6839
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	66	1584	6840
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	91	2184	6841
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	91	2184	6842
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	58	1392	6843
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	98	2352	6844
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	92	2208	6845
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	51	1224	6846
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	55	1320	6847
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	97	2328	6848
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	77	1848	6849
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	60	1440	6850
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	96	2304	6851
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	98	2352	6852
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	68	1632	6853
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	51	1224	6854
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	96	2304	6855
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	78	1872	6856
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	61	1464	6857
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	81	1944	6858
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	90	2160	6859
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	58	1392	6860
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	59	1416	6861
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	89	2136	6862
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	63	1512	6863
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	65	1560	6864
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	100	2400	6865
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	92	2208	6866
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	68	1632	6867
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	58	1392	6868
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	64	1536	6869
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	61	1464	6870
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	73	1752	6871
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	90	2160	6872
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	98	2352	6873
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	50	1200	6874
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	53	1272	6875
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	65	1560	6876
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	92	2208	6877
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	57	1368	6878
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	61	1464	6879
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	65	1560	6880
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	86	2064	6881
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	57	1368	6882
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	80	1920	6883
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	67	1608	6884
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	74	1776	6885
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	69	1656	6886
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	96	2304	6887
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	88	2112	6888
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	51	1224	6889
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	74	1776	6890
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	60	1440	6891
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	88	2112	6892
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	99	2376	6893
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	61	1464	6894
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	66	1584	6895
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	50	1200	6896
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	97	2328	6897
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	83	1992	6898
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	81	1944	6899
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	60	1440	6900
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	61	1464	6901
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	71	1704	6902
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	84	2016	6903
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	61	1464	6904
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	56	1344	6905
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	100	2400	6906
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	98	2352	6907
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	94	2256	6908
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	54	1296	6909
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	83	1992	6910
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	90	2160	6911
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	97	2328	6912
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	64	1536	6913
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	58	1392	6914
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	78	1872	6915
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	83	1992	6916
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	62	1488	6917
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	57	1368	6918
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	74	1776	6919
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	50	1200	6920
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	58	1392	6921
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	78	1872	6922
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	79	1896	6923
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	67	1608	6924
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	58	1392	6925
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	77	1848	6926
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	55	1320	6927
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	59	1416	6928
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	54	1296	6929
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	71	1704	6930
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	80	1920	6931
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	78	1872	6932
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	58	1392	6933
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	63	1512	6934
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	50	1200	6935
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	86	2064	6936
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	92	2208	6937
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	91	2184	6938
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	86	2064	6939
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	85	2040	6940
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	80	1920	6941
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	86	2064	6942
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	87	2088	6943
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	64	1536	6944
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	60	1440	6945
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	73	1752	6946
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	90	2160	6947
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	92	2208	6948
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	87	2088	6949
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	96	2304	6950
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	67	1608	6951
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	69	1656	6952
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	50	1200	6953
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	69	1656	6954
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	67	1608	6955
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	71	1704	6956
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	64	1536	6957
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	64	1536	6958
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	75	1800	6959
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	59	1416	6960
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	58	1392	6961
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	50	1200	6962
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	68	1632	6963
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	58	1392	6964
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	74	1776	6965
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	91	2184	6966
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	85	2040	6967
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	53	1272	6968
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	97	2328	6969
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	74	1776	6970
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	92	2208	6971
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	90	2160	6972
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	55	1320	6973
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	87	2088	6974
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	71	1704	6975
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	81	1944	6976
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	73	1752	6977
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	96	2304	6978
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	63	1512	6979
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	65	1560	6980
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	78	1872	6981
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	96	2304	6982
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	57	1368	6983
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	55	1320	6984
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	56	1344	6985
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	68	1632	6986
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	72	1728	6987
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	79	1896	6988
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	74	1776	6989
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	71	1704	6990
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	62	1488	6991
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	94	2256	6992
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	54	1296	6993
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	76	1824	6994
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	74	1776	6995
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	100	2400	6996
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	50	1200	6997
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	72	1728	6998
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	79	1896	6999
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	50	1200	7000
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	65	1560	7001
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	57	1368	7002
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	57	1368	7003
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	95	2280	7004
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	92	2208	7005
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	93	2232	7006
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	66	1584	7007
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	63	1512	7008
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	67	1608	7009
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	51	1224	7010
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	50	1200	7011
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	71	1704	7012
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	52	1248	7013
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	63	1512	7014
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	71	1704	7015
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	78	1872	7016
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	83	1992	7017
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	76	1824	7018
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	86	2064	7019
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	57	1368	7020
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	94	2256	7021
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	98	2352	7022
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	75	1800	7023
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	76	1824	7024
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	87	2088	7025
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	57	1368	7026
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	92	2208	7027
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	92	2208	7028
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	80	1920	7029
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	69	1656	7030
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	63	1512	7031
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	70	1680	7032
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	92	2208	7033
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	52	1248	7034
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	71	1704	7035
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	60	1440	7036
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	70	1680	7037
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	91	2184	7038
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	68	1632	7039
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	75	1800	7040
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	58	1392	7041
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	97	2328	7042
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	97	2328	7043
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	96	2304	7044
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	72	1728	7045
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	90	2160	7046
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	87	2088	7047
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	66	1584	7048
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	55	1320	7049
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	97	2328	7050
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	72	1728	7051
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	67	1608	7052
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	88	2112	7053
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	66	1584	7054
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	80	1920	7055
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	85	2040	7056
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	89	2136	7057
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	91	2184	7058
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	78	1872	7059
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	54	1296	7060
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	63	1512	7061
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	95	2280	7062
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	61	1464	7063
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	50	1200	7064
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	63	1512	7065
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	73	1752	7066
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	98	2352	7067
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	71	1704	7068
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	78	1872	7069
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	84	2016	7070
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	73	1752	7071
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	67	1608	7072
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	50	1200	7073
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	55	1320	7074
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	68	1632	7075
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	97	2328	7076
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	88	2112	7077
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	71	1704	7078
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	83	1992	7079
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	57	1368	7080
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	99	2376	7081
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	89	2136	7082
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	84	2016	7083
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	90	2160	7084
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	80	1920	7085
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	93	2232	7086
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	63	1512	7087
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	73	1752	7088
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	86	2064	7089
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	92	2208	7090
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	84	2016	7091
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	99	2376	7092
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	63	1512	7093
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	55	1320	7094
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	57	1368	7095
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	61	1464	7096
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	84	2016	7097
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	55	1320	7098
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	78	1872	7099
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	86	2064	7100
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	91	2184	7101
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	94	2256	7102
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	76	1824	7103
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	74	1776	7104
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	56	1344	7105
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	87	2088	7106
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	88	2112	7107
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	86	2064	7108
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	89	2136	7109
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	94	2256	7110
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	75	1800	7111
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	75	1800	7112
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	93	2232	7113
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	75	1800	7114
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	76	1824	7115
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	68	1632	7116
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	76	1824	7117
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	89	2136	7118
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	78	1872	7119
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	83	1992	7120
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	97	2328	7121
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	64	1536	7122
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	59	1416	7123
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	94	2256	7124
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	73	1752	7125
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	67	1608	7126
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	89	2136	7127
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	100	2400	7128
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	75	1800	7129
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	60	1440	7130
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	83	1992	7131
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	90	2160	7132
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	85	2040	7133
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	52	1248	7134
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	74	1776	7135
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	84	2016	7136
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	81	1944	7137
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	92	2208	7138
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	97	2328	7139
456789	2018-01-01 00:00:00	2018-04-02 07:12:00	61	1464	7140
456789	2018-04-02 07:12:00	2018-07-02 14:24:00	94	2256	7141
456789	2018-07-02 14:24:00	2018-10-01 21:36:00	65	1560	7142
456789	2018-10-01 21:36:00	2019-01-01 04:48:00	62	1488	7143
456789	2019-01-01 04:48:00	2019-04-02 12:00:00	52	1248	7144
456789	2019-04-02 12:00:00	2019-07-02 19:12:00	54	1296	7145
456789	2019-07-02 19:12:00	2019-10-02 02:24:00	65	1560	7146
456789	2019-10-02 02:24:00	2020-01-01 09:36:00	96	2304	7147
456789	2020-01-01 09:36:00	2020-04-01 16:48:00	92	2208	7148
456789	2020-04-01 16:48:00	2020-07-02 00:00:00	64	1536	7149
456789	2020-07-02 00:00:00	2020-10-01 07:12:00	100	2400	7150
456789	2020-10-01 07:12:00	2020-12-31 14:24:00	95	2280	7151
456789	2020-12-31 14:24:00	2021-04-01 21:36:00	60	1440	7152
456789	2021-04-01 21:36:00	2021-07-02 04:48:00	81	1944	7153
456789	2021-07-02 04:48:00	2021-10-01 12:00:00	99	2376	7154
456789	2021-10-01 12:00:00	2021-12-31 19:12:00	98	2352	7155
456789	2021-12-31 19:12:00	2022-04-02 02:24:00	79	1896	7156
456789	2022-04-02 02:24:00	2022-07-02 09:36:00	70	1680	7157
456789	2022-07-02 09:36:00	2022-10-01 16:48:00	73	1752	7158
456789	2022-10-01 16:48:00	2023-01-01 00:00:00	84	2016	7159
567890	2018-01-01 00:00:00	2018-04-02 07:12:00	52	1248	7160
567890	2018-04-02 07:12:00	2018-07-02 14:24:00	66	1584	7161
567890	2018-07-02 14:24:00	2018-10-01 21:36:00	82	1968	7162
567890	2018-10-01 21:36:00	2019-01-01 04:48:00	98	2352	7163
567890	2019-01-01 04:48:00	2019-04-02 12:00:00	60	1440	7164
567890	2019-04-02 12:00:00	2019-07-02 19:12:00	72	1728	7165
567890	2019-07-02 19:12:00	2019-10-02 02:24:00	67	1608	7166
567890	2019-10-02 02:24:00	2020-01-01 09:36:00	71	1704	7167
567890	2020-01-01 09:36:00	2020-04-01 16:48:00	55	1320	7168
567890	2020-04-01 16:48:00	2020-07-02 00:00:00	93	2232	7169
567890	2020-07-02 00:00:00	2020-10-01 07:12:00	74	1776	7170
567890	2020-10-01 07:12:00	2020-12-31 14:24:00	99	2376	7171
567890	2020-12-31 14:24:00	2021-04-01 21:36:00	56	1344	7172
567890	2021-04-01 21:36:00	2021-07-02 04:48:00	52	1248	7173
567890	2021-07-02 04:48:00	2021-10-01 12:00:00	83	1992	7174
567890	2021-10-01 12:00:00	2021-12-31 19:12:00	56	1344	7175
567890	2021-12-31 19:12:00	2022-04-02 02:24:00	71	1704	7176
567890	2022-04-02 02:24:00	2022-07-02 09:36:00	100	2400	7177
567890	2022-07-02 09:36:00	2022-10-01 16:48:00	55	1320	7178
567890	2022-10-01 16:48:00	2023-01-01 00:00:00	55	1320	7179
678901	2018-01-01 00:00:00	2018-04-02 07:12:00	98	2352	7180
678901	2018-04-02 07:12:00	2018-07-02 14:24:00	81	1944	7181
678901	2018-07-02 14:24:00	2018-10-01 21:36:00	92	2208	7182
678901	2018-10-01 21:36:00	2019-01-01 04:48:00	54	1296	7183
678901	2019-01-01 04:48:00	2019-04-02 12:00:00	75	1800	7184
678901	2019-04-02 12:00:00	2019-07-02 19:12:00	70	1680	7185
678901	2019-07-02 19:12:00	2019-10-02 02:24:00	87	2088	7186
678901	2019-10-02 02:24:00	2020-01-01 09:36:00	79	1896	7187
678901	2020-01-01 09:36:00	2020-04-01 16:48:00	85	2040	7188
678901	2020-04-01 16:48:00	2020-07-02 00:00:00	73	1752	7189
678901	2020-07-02 00:00:00	2020-10-01 07:12:00	62	1488	7190
678901	2020-10-01 07:12:00	2020-12-31 14:24:00	53	1272	7191
678901	2020-12-31 14:24:00	2021-04-01 21:36:00	94	2256	7192
678901	2021-04-01 21:36:00	2021-07-02 04:48:00	71	1704	7193
678901	2021-07-02 04:48:00	2021-10-01 12:00:00	97	2328	7194
678901	2021-10-01 12:00:00	2021-12-31 19:12:00	95	2280	7195
678901	2021-12-31 19:12:00	2022-04-02 02:24:00	95	2280	7196
678901	2022-04-02 02:24:00	2022-07-02 09:36:00	76	1824	7197
678901	2022-07-02 09:36:00	2022-10-01 16:48:00	50	1200	7198
678901	2022-10-01 16:48:00	2023-01-01 00:00:00	50	1200	7199
789012	2018-01-01 00:00:00	2018-04-02 07:12:00	96	2304	7200
789012	2018-04-02 07:12:00	2018-07-02 14:24:00	88	2112	7201
789012	2018-07-02 14:24:00	2018-10-01 21:36:00	69	1656	7202
789012	2018-10-01 21:36:00	2019-01-01 04:48:00	84	2016	7203
789012	2019-01-01 04:48:00	2019-04-02 12:00:00	70	1680	7204
789012	2019-04-02 12:00:00	2019-07-02 19:12:00	94	2256	7205
789012	2019-07-02 19:12:00	2019-10-02 02:24:00	92	2208	7206
789012	2019-10-02 02:24:00	2020-01-01 09:36:00	78	1872	7207
789012	2020-01-01 09:36:00	2020-04-01 16:48:00	53	1272	7208
789012	2020-04-01 16:48:00	2020-07-02 00:00:00	85	2040	7209
789012	2020-07-02 00:00:00	2020-10-01 07:12:00	65	1560	7210
789012	2020-10-01 07:12:00	2020-12-31 14:24:00	91	2184	7211
789012	2020-12-31 14:24:00	2021-04-01 21:36:00	97	2328	7212
789012	2021-04-01 21:36:00	2021-07-02 04:48:00	85	2040	7213
789012	2021-07-02 04:48:00	2021-10-01 12:00:00	79	1896	7214
789012	2021-10-01 12:00:00	2021-12-31 19:12:00	76	1824	7215
789012	2021-12-31 19:12:00	2022-04-02 02:24:00	80	1920	7216
789012	2022-04-02 02:24:00	2022-07-02 09:36:00	81	1944	7217
789012	2022-07-02 09:36:00	2022-10-01 16:48:00	51	1224	7218
789012	2022-10-01 16:48:00	2023-01-01 00:00:00	65	1560	7219
890123	2018-01-01 00:00:00	2018-04-02 07:12:00	88	2112	7220
890123	2018-04-02 07:12:00	2018-07-02 14:24:00	88	2112	7221
890123	2018-07-02 14:24:00	2018-10-01 21:36:00	72	1728	7222
890123	2018-10-01 21:36:00	2019-01-01 04:48:00	87	2088	7223
890123	2019-01-01 04:48:00	2019-04-02 12:00:00	65	1560	7224
890123	2019-04-02 12:00:00	2019-07-02 19:12:00	84	2016	7225
890123	2019-07-02 19:12:00	2019-10-02 02:24:00	84	2016	7226
890123	2019-10-02 02:24:00	2020-01-01 09:36:00	98	2352	7227
890123	2020-01-01 09:36:00	2020-04-01 16:48:00	55	1320	7228
890123	2020-04-01 16:48:00	2020-07-02 00:00:00	95	2280	7229
890123	2020-07-02 00:00:00	2020-10-01 07:12:00	58	1392	7230
890123	2020-10-01 07:12:00	2020-12-31 14:24:00	67	1608	7231
890123	2020-12-31 14:24:00	2021-04-01 21:36:00	79	1896	7232
890123	2021-04-01 21:36:00	2021-07-02 04:48:00	53	1272	7233
890123	2021-07-02 04:48:00	2021-10-01 12:00:00	88	2112	7234
890123	2021-10-01 12:00:00	2021-12-31 19:12:00	91	2184	7235
890123	2021-12-31 19:12:00	2022-04-02 02:24:00	57	1368	7236
890123	2022-04-02 02:24:00	2022-07-02 09:36:00	61	1464	7237
890123	2022-07-02 09:36:00	2022-10-01 16:48:00	89	2136	7238
890123	2022-10-01 16:48:00	2023-01-01 00:00:00	74	1776	7239
901234	2018-01-01 00:00:00	2018-04-02 07:12:00	87	2088	7240
901234	2018-04-02 07:12:00	2018-07-02 14:24:00	63	1512	7241
901234	2018-07-02 14:24:00	2018-10-01 21:36:00	64	1536	7242
901234	2018-10-01 21:36:00	2019-01-01 04:48:00	81	1944	7243
901234	2019-01-01 04:48:00	2019-04-02 12:00:00	93	2232	7244
901234	2019-04-02 12:00:00	2019-07-02 19:12:00	65	1560	7245
901234	2019-07-02 19:12:00	2019-10-02 02:24:00	55	1320	7246
901234	2019-10-02 02:24:00	2020-01-01 09:36:00	90	2160	7247
901234	2020-01-01 09:36:00	2020-04-01 16:48:00	55	1320	7248
901234	2020-04-01 16:48:00	2020-07-02 00:00:00	84	2016	7249
901234	2020-07-02 00:00:00	2020-10-01 07:12:00	51	1224	7250
901234	2020-10-01 07:12:00	2020-12-31 14:24:00	89	2136	7251
901234	2020-12-31 14:24:00	2021-04-01 21:36:00	97	2328	7252
901234	2021-04-01 21:36:00	2021-07-02 04:48:00	66	1584	7253
901234	2021-07-02 04:48:00	2021-10-01 12:00:00	91	2184	7254
901234	2021-10-01 12:00:00	2021-12-31 19:12:00	60	1440	7255
901234	2021-12-31 19:12:00	2022-04-02 02:24:00	100	2400	7256
901234	2022-04-02 02:24:00	2022-07-02 09:36:00	53	1272	7257
901234	2022-07-02 09:36:00	2022-10-01 16:48:00	70	1680	7258
901234	2022-10-01 16:48:00	2023-01-01 00:00:00	91	2184	7259
\.


--
-- TOC entry 3448 (class 0 OID 33622)
-- Dependencies: 225
-- Data for Name: Staff; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Staff" ("Stf_Code", "Position", "Resps", "Salary", stf_name) FROM stdin;
123123	Client Manager	Keeps track of the clients and communicates with them. Creates client offers.	45000	Jimmy Landers
456789	Sales Manager	Responsible for creating and executing sales strategies. Manages sales team.	55000	Alice Smith
789012	Marketing Coordinator	Assists in developing and executing marketing campaigns. Manages social media.	40000	Bob Johnson
890123	Financial Analyst	Conducts financial analysis and provides recommendations. Prepares financial reports.	60000	Caroline Lee
345678	IT Specialist	Provides technical support to employees. Manages company network.	50000	David Chen
901234	HR Generalist	Assists in recruiting, onboarding and training. Manages employee records.	45000	Emily Wong
567890	Operations Manager	Oversees day-to-day operations. Develops and implements operational policies.	70000	Franklin Rodriguez
678901	Customer Serv Representative	Assists customers with inquiries and issues. Provides customer support.	35000	Grace Kim
113322	Client Manager	Keeps track of the clients and communicates with them. Creates client offers.	55000	Sarah Johnson
134523	Sales Manager	Responsible for creating and executing sales strategies. Manages sales team.	65000	Tom Smith
678902	Customer Serv Representative	Assists customers with inquiries and issues. Provides customer support.	35000	Johnny Depth
\.


--
-- TOC entry 3449 (class 0 OID 33627)
-- Dependencies: 226
-- Data for Name: Violation; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab."Violation" ("Violation_Code", "Penalty_Code", rtr_viol_code) FROM stdin;
1	201	152
2	105	128
3	210	147
4	104	160
5	212	133
6	154	165
7	101	152
8	135	143
9	116	144
10	189	160
11	144	153
12	182	155
13	143	133
14	185	153
15	177	135
16	178	155
17	112	125
18	191	158
19	110	162
20	176	152
21	107	140
22	104	125
23	120	142
24	213	156
25	154	142
26	134	148
27	180	138
28	109	139
29	106	121
30	194	161
31	134	138
32	210	154
33	154	134
34	130	157
35	124	124
36	195	129
37	132	126
38	106	159
39	137	156
40	108	160
41	136	134
42	144	150
43	135	137
44	165	130
45	193	154
46	209	162
47	202	131
48	206	125
49	114	142
50	161	130
51	153	136
52	211	154
53	115	132
54	128	130
55	122	127
56	103	157
57	164	133
58	187	142
59	198	159
60	216	125
61	210	142
62	102	155
63	214	127
64	186	125
65	152	122
66	115	147
67	163	148
68	143	121
69	120	143
70	179	141
71	150	136
72	219	145
73	142	157
74	149	156
75	182	134
76	189	123
77	203	143
78	129	128
79	128	135
80	141	141
81	168	144
82	147	158
83	174	157
84	107	136
85	148	153
86	110	123
87	216	133
88	205	140
89	116	156
90	173	124
91	152	131
92	103	158
93	171	160
94	147	155
95	139	137
96	119	126
97	114	141
98	156	128
99	125	144
100	203	145
\.


--
-- TOC entry 3450 (class 0 OID 33630)
-- Dependencies: 227
-- Data for Name: insurance_dict; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab.insurance_dict (insur_code, insur_price, insure_name, insure_desc, "Mod_Code") FROM stdin;
100001	25	Basic insurance	Covers mild car damage such as scratches.	294832
100002	75	Collision insurance	Covers damage to your car from an accident.	294832
100003	125	Comprehensive insurance	Covers damage to your car from events such as theft, vandalism, or natural disasters.	294832
100004	30	Basic insurance	Covers mild car damage such as scratches.	345678
100005	85	Collision insurance	Covers damage to your car from an accident.	345678
100006	135	Comprehensive insurance	Covers damage to your car from events such as theft, vandalism, or natural disasters.	345678
100007	35	Basic insurance	Covers mild car damage such as scratches.	456789
100008	95	Collision insurance	Covers damage to your car from an accident.	456789
100009	145	Comprehensive insurance	Covers damage to your car from events such as theft, vandalism, or natural disasters.	456789
100010	40	Basic insurance	Covers mild car damage such as scratches.	567890
100011	105	Collision insurance	Covers damage to your car from an accident.	567890
100012	155	Comprehensive insurance	Covers damage to your car from events such as theft, vandalism, or natural disasters.	567890
100013	45	Basic insurance	Covers mild car damage such as scratches.	678901
100014	115	Collision insurance	Covers damage to your car from an accident.	678901
100015	165	Comprehensive insurance	Covers damage to your car from events such as theft, vandalism, or natural disasters.	678901
100016	50	Basic insurance	Covers mild car damage such as scratches.	789012
100017	125	Collision insurance	Covers damage to your car from an accident.	789012
100018	175	Comprehensive insurance	Covers damage to your car from events such as theft, vandalism, or natural disasters.	789012
100021	200	Comprehensive insurance	Covers damage from theft, fire, and weather-related incidents.	890123
100022	150	Liability insurance	Covers damages to other people or their property caused by the insured vehicle.	890123
100023	100	Personal injury protection	Covers medical expenses and lost wages for the driver and passengers in the event of an accident.	890123
100024	250	Comprehensive insurance	Covers damage from theft, fire, and weather-related incidents.	901234
100025	200	Liability insurance	Covers damages to other people or their property caused by the insured vehicle.	901234
100026	150	Personal injury protection	Covers medical expenses and lost wages for the driver and passengers in the event of an accident.	901234
\.


--
-- TOC entry 3451 (class 0 OID 33633)
-- Dependencies: 228
-- Data for Name: rtr_dict; Type: TABLE DATA; Schema: lab; Owner: postgres
--

COPY lab.rtr_dict (rtr_viol_code, viol_fee, viol_type, viol_descript) FROM stdin;
121	12.34	Speeding	Exceeding the maximum speed limit by less than 20 km/h.
122	25	Speeding	Exceeding the maximum speed limit by 20-40 km/h.
123	49.22	Speeding	Exceeding the maximum speed limit by 40-60 km/h.
124	74.16	Speeding	Exceeding the maximum speed limit by 60-80 km/h.
125	123.61	Speeding	Exceeding the maximum speed limit by more than 80 km/h.
126	12.34	Running a red light	Driving through a red light or stop sign.
127	18.51	Driving under influence	Driving under the influence of alcohol or drugs.
128	12.34	Failure to yield	Failing to yield to another driver or pedestrian.
129	74.16	Reckless driving	Driving in a manner that endangers other drivers.
130	37.08	Driving without a license	Driving without a valid driver’s license.
131	12.34	Improper lane change	Changing lanes without signaling or cutting off other drivers.
132	49.22	Following too closely	Following another vehicle too closely, also known as tailgating.
133	24.61	Failure to stop at a stop sign	Failing to come to a complete stop at a stop sign.
134	49.22	Illegal U-turn	Making a U-turn where it is prohibited by law.
135	123.61	Driving in a carpool lane	Driving in a carpool lane when not authorized or without the required number of passengers.
136	74.16	Driving with a suspended license	Driving with a suspended or revoked driver’s license.
137	123.61	Leaving the scene of an accident	Failing to stop and exchange information after being involved in an accident.
138	74.16	Driving too slowly	Driving significantly below the speed limit and impeding the flow of traffic.
139	111.94	Driving in a bike lane	Driving in a bike lane when not authorized or without a valid reason.
140	18.51	Driving with expired registration	Driving a vehicle with expired registration tags or without valid registration documentation.
141	49.22	Distracted driving	Driving while distracted by phone, food, or other activities.
142	12.34	Seatbelt violation	Not wearing a seatbelt while driving or riding in a vehicle.
143	74.16	Hit and run	Leaving the scene of an accident without stopping to exchange information.
144	37.08	Improper passing	Passing another vehicle in an unsafe or illegal manner.
145	61.44	Driving without insurance	Driving a vehicle without proper insurance coverage.
146	123.61	Street racing	Participating in a race or speed competition on public roads.
147	49.22	Driving too slow	Driving significantly below the posted speed limit and impeding traffic flow.
148	74.16	Driving in a bike lane	Driving a vehicle in a lane designated for bicycles.
149	25	Excessive honking	Using the vehicle horn excessively or for no reason.
150	12.34	Blocking an intersection	Entering an intersection without enough space to clear it, causing congestion.
151	61.44	Driving with an open container	Having an open container of alcohol in the passenger compartment of a vehicle.
152	49.22	Failing to signal	Failing to signal when turning or changing lanes.
153	123.61	Driving the wrong way	Driving in the opposite direction of traffic on a one-way street or highway.
154	74.16	Running a stop sign	Driving through a stop sign without coming to a complete stop.
155	111.94	Driving without headlights at night	Driving without turning on headlights when required, typically at night or in low visibility conditions.
156	37.08	Passing a school bus	Failing to stop for a school bus when its lights are flashing and its stop sign is extended.
157	123.61	Drag racing	Participating in a race or speed competition on public roads with one or more other vehicles.
158	25	Driving with a cracked windshield	Driving with a windshield that is cracked or otherwise damaged and impairs the drivers vision.
159	74.16	Failure to use turn signals	Failing to use turn signals when required by law, such as when changing lanes or turning.
160	49.22	Driving with an expired license	Driving with a drivers license that has expired and is no longer valid.
161	111.94	Driving without a seatbelt	Driving without wearing a seatbelt or allowing passengers to ride without wearing seatbelts.
162	74.16	Driving on a suspended license	Driving with a drivers license that has been suspended or revoked by the state.
163	49.22	Driving too fast for conditions	Driving faster than is safe or reasonable given the weather, road, or traffic conditions.
164	123.61	Driving without headlights when required	Driving without turning on headlights when required, typically at night or in low visibility conditions.
165	61.44	Failure to yield to emergency vehicle	Failing to yield to an emergency vehicle with its lights and sirens on, such as a police car or ambulance.
\.


--
-- TOC entry 3452 (class 0 OID 58013)
-- Dependencies: 229
-- Data for Name: carcount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.carcount (count) FROM stdin;
3
\.


--
-- TOC entry 3253 (class 2606 OID 33637)
-- Name: Accidents Accidents_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Accidents"
    ADD CONSTRAINT "Accidents_pkey" PRIMARY KEY ("Accident_DT");


--
-- TOC entry 3255 (class 2606 OID 33639)
-- Name: Auto Auto_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Auto"
    ADD CONSTRAINT "Auto_pkey" PRIMARY KEY ("Auto_Code");


--
-- TOC entry 3257 (class 2606 OID 33641)
-- Name: Bonus_Card Bonus_Card_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Bonus_Card"
    ADD CONSTRAINT "Bonus_Card_pkey" PRIMARY KEY ("BC_Code");


--
-- TOC entry 3259 (class 2606 OID 33643)
-- Name: Client Client_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT "Client_pkey" PRIMARY KEY ("Cl_Code");


--
-- TOC entry 3267 (class 2606 OID 33645)
-- Name: Contract Contract_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Contract_pkey" PRIMARY KEY ("Contr_Code");


--
-- TOC entry 3269 (class 2606 OID 33647)
-- Name: Extension Extension_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Extension"
    ADD CONSTRAINT "Extension_pkey" PRIMARY KEY ("Extension_Id");


--
-- TOC entry 3271 (class 2606 OID 33649)
-- Name: Model Model_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Model"
    ADD CONSTRAINT "Model_pkey" PRIMARY KEY ("Mod_Code");


--
-- TOC entry 3273 (class 2606 OID 33651)
-- Name: Penalties Penalties_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Penalties"
    ADD CONSTRAINT "Penalties_pkey" PRIMARY KEY ("Penalty_Code");


--
-- TOC entry 3275 (class 2606 OID 33653)
-- Name: Price Price_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Price"
    ADD CONSTRAINT "Price_pkey" PRIMARY KEY ("Price_Code");


--
-- TOC entry 3277 (class 2606 OID 33655)
-- Name: Staff Staff_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Staff"
    ADD CONSTRAINT "Staff_pkey" PRIMARY KEY ("Stf_Code");


--
-- TOC entry 3279 (class 2606 OID 33657)
-- Name: Violation Violation_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Violation"
    ADD CONSTRAINT "Violation_pkey" PRIMARY KEY ("Violation_Code");


--
-- TOC entry 3281 (class 2606 OID 33659)
-- Name: insurance_dict insurance_dict_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab.insurance_dict
    ADD CONSTRAINT insurance_dict_pkey PRIMARY KEY (insur_code);


--
-- TOC entry 3283 (class 2606 OID 33661)
-- Name: rtr_dict rtr_dict_pkey; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab.rtr_dict
    ADD CONSTRAINT rtr_dict_pkey PRIMARY KEY (rtr_viol_code);


--
-- TOC entry 3261 (class 2606 OID 33663)
-- Name: Client unq_email; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT unq_email UNIQUE ("Email");


--
-- TOC entry 3263 (class 2606 OID 33665)
-- Name: Client unq_psprt; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT unq_psprt UNIQUE ("Passport_Data");


--
-- TOC entry 3265 (class 2606 OID 33667)
-- Name: Client unq_telnum; Type: CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT unq_telnum UNIQUE ("Tel_Num");


--
-- TOC entry 3296 (class 2620 OID 66194)
-- Name: Contract late_fee_trigger; Type: TRIGGER; Schema: lab; Owner: postgres
--

CREATE TRIGGER late_fee_trigger AFTER UPDATE ON lab."Contract" FOR EACH ROW EXECUTE FUNCTION public.calculate_late_fee();


--
-- TOC entry 3291 (class 2606 OID 33668)
-- Name: Penalties Accident_DT; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Penalties"
    ADD CONSTRAINT "Accident_DT" FOREIGN KEY ("Accident_DT") REFERENCES lab."Accidents"("Accident_DT") NOT VALID;


--
-- TOC entry 3287 (class 2606 OID 33673)
-- Name: Contract Auto_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Auto_Code" FOREIGN KEY ("Auto_Code") REFERENCES lab."Auto"("Auto_Code") NOT VALID;


--
-- TOC entry 3286 (class 2606 OID 33678)
-- Name: Bonus_Card Cl_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Bonus_Card"
    ADD CONSTRAINT "Cl_Code" FOREIGN KEY ("Cl_Code") REFERENCES lab."Client"("Cl_Code") NOT VALID;


--
-- TOC entry 3288 (class 2606 OID 33683)
-- Name: Contract Cl_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Cl_Code" FOREIGN KEY ("Cl_Code") REFERENCES lab."Client"("Cl_Code") NOT VALID;


--
-- TOC entry 3290 (class 2606 OID 33688)
-- Name: Extension Contr_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Extension"
    ADD CONSTRAINT "Contr_Code" FOREIGN KEY ("Contr_Code") REFERENCES lab."Contract"("Contr_Code") NOT VALID;


--
-- TOC entry 3284 (class 2606 OID 33693)
-- Name: Accidents Contr_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Accidents"
    ADD CONSTRAINT "Contr_Code" FOREIGN KEY ("Contr_Code") REFERENCES lab."Contract"("Contr_Code") NOT VALID;


--
-- TOC entry 3292 (class 2606 OID 33698)
-- Name: Price Mod_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Price"
    ADD CONSTRAINT "Mod_Code" FOREIGN KEY ("Mod_Code") REFERENCES lab."Model"("Mod_Code") NOT VALID;


--
-- TOC entry 3285 (class 2606 OID 33703)
-- Name: Auto Mod_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Auto"
    ADD CONSTRAINT "Mod_Code" FOREIGN KEY ("Mod_Code") REFERENCES lab."Model"("Mod_Code") NOT VALID;


--
-- TOC entry 3295 (class 2606 OID 33708)
-- Name: insurance_dict Mod_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab.insurance_dict
    ADD CONSTRAINT "Mod_Code" FOREIGN KEY ("Mod_Code") REFERENCES lab."Model"("Mod_Code") NOT VALID;


--
-- TOC entry 3293 (class 2606 OID 33713)
-- Name: Violation Penalty_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Violation"
    ADD CONSTRAINT "Penalty_Code" FOREIGN KEY ("Penalty_Code") REFERENCES lab."Penalties"("Penalty_Code") NOT VALID;


--
-- TOC entry 3289 (class 2606 OID 33718)
-- Name: Contract Stf_Code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Stf_Code" FOREIGN KEY ("Stf_Code") REFERENCES lab."Staff"("Stf_Code") NOT VALID;


--
-- TOC entry 3294 (class 2606 OID 33723)
-- Name: Violation rtr_viol_code; Type: FK CONSTRAINT; Schema: lab; Owner: postgres
--

ALTER TABLE ONLY lab."Violation"
    ADD CONSTRAINT rtr_viol_code FOREIGN KEY (rtr_viol_code) REFERENCES lab.rtr_dict(rtr_viol_code) NOT VALID;


-- Completed on 2023-09-05 14:21:43

--
-- PostgreSQL database dump complete
--

