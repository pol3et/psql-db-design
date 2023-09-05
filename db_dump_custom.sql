PGDMP                         {            mydb    15.2    15.2 J               0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    33566    mydb    DATABASE        CREATE DATABASE mydb WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'English_United States.1251';
    DROP DATABASE mydb;
                postgres    false                        2615    33567    lab    SCHEMA        CREATE SCHEMA lab;
    DROP SCHEMA lab;
                postgres    false                        3079    33568 	   adminpack 	   EXTENSION     A   CREATE EXTENSION IF NOT EXISTS adminpack WITH SCHEMA pg_catalog;
    DROP EXTENSION adminpack;
                   false            �           0    0    EXTENSION adminpack    COMMENT     M   COMMENT ON EXTENSION adminpack IS 'administrative functions for PostgreSQL';
                        false    2            [           1247    33579    non_neg_money    DOMAIN     u   CREATE DOMAIN public.non_neg_money AS real
	CONSTRAINT non_neg_money_check CHECK ((VALUE >= (0)::double precision));
 "   DROP DOMAIN public.non_neg_money;
       public          postgres    false            _           1247    33582    non_negative_bigint    DOMAIN     o   CREATE DOMAIN public.non_negative_bigint AS bigint
	CONSTRAINT non_negative_bigint_check CHECK ((VALUE >= 0));
 (   DROP DOMAIN public.non_negative_bigint;
       public          postgres    false            c           1247    33585    non_negative_integer    DOMAIN     r   CREATE DOMAIN public.non_negative_integer AS integer
	CONSTRAINT non_negative_integer_check CHECK ((VALUE >= 0));
 )   DROP DOMAIN public.non_negative_integer;
       public          postgres    false            �            1255    66191    calculate_late_fee()    FUNCTION     [  CREATE FUNCTION public.calculate_late_fee() RETURNS trigger
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
 +   DROP FUNCTION public.calculate_late_fee();
       public          postgres    false            �            1255    58012 "   sp_get_car_count_by_model(integer) 	   PROCEDURE       CREATE PROCEDURE public.sp_get_car_count_by_model(IN mod_code integer, OUT carcount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT COUNT(*) INTO carCount
    FROM lab."Auto" a
    JOIN lab."Model" m USING ("Mod_Code")
    WHERE m."Mod_Code" = mod_Code;
END;
$$;
 \   DROP PROCEDURE public.sp_get_car_count_by_model(IN mod_code integer, OUT carcount integer);
       public          postgres    false            �            1255    58011    sp_getcarcountbymodel(integer) 	   PROCEDURE       CREATE PROCEDURE public.sp_getcarcountbymodel(IN mod_code integer, OUT carcount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT COUNT(*) INTO carCount
    FROM lab."Auto" a
    JOIN lab."Model" m USING ("Mod_Code")
    WHERE m."Mod_Code" = mod_Code;
	
END;
$$;
 X   DROP PROCEDURE public.sp_getcarcountbymodel(IN mod_code integer, OUT carcount integer);
       public          postgres    false            �            1255    58004 (   sp_getcarcountbymodel(character varying) 	   PROCEDURE       CREATE PROCEDURE public.sp_getcarcountbymodel(IN mod_name character varying, OUT carcount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT COUNT(*) INTO carCount
    FROM lab."Auto" a
    JOIN lab."Model" m ON a."Mod_Code" = m."Mod_Code"
    WHERE m."Name" = mod_Name;
END;
$$;
 b   DROP PROCEDURE public.sp_getcarcountbymodel(IN mod_name character varying, OUT carcount integer);
       public          postgres    false            �            1255    58001 *   sp_issuecartocl(integer, integer, integer) 	   PROCEDURE     �  CREATE PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN auto_code integer, IN rent_h integer)
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
 d   DROP PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN auto_code integer, IN rent_h integer);
       public          postgres    false            �            1255    58002 3   sp_issuecartocl(integer, integer, integer, integer) 	   PROCEDURE     �  CREATE PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN stf_code integer, IN auto_code integer, IN rent_h integer)
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
 y   DROP PROCEDURE public.sp_issuecartocl(IN cl_code integer, IN stf_code integer, IN auto_code integer, IN rent_h integer);
       public          postgres    false            �            1255    57999    sp_writeoffcarsbyyear(integer) 	   PROCEDURE       CREATE PROCEDURE public.sp_writeoffcarsbyyear(IN targetyear integer)
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
 D   DROP PROCEDURE public.sp_writeoffcarsbyyear(IN targetyear integer);
       public          postgres    false            �            1259    33587 	   Accidents    TABLE     
  CREATE TABLE lab."Accidents" (
    "Accident_DT" timestamp(2) without time zone NOT NULL,
    "Contr_Code" public.non_negative_integer NOT NULL,
    "Place" character varying(100),
    "Damage" character varying(300) NOT NULL,
    "Cl_Is_Guilty" boolean NOT NULL
);
    DROP TABLE lab."Accidents";
       lab         heap    postgres    false    867    7            �            1259    33590    Auto    TABLE       CREATE TABLE lab."Auto" (
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
    DROP TABLE lab."Auto";
       lab         heap    postgres    false    867    867    867    7    867            �            1259    33594 
   Bonus_Card    TABLE       CREATE TABLE lab."Bonus_Card" (
    "BC_Code" public.non_negative_bigint NOT NULL,
    "Cl_Code" public.non_negative_integer NOT NULL,
    "Bonus_Sum" public.non_negative_integer NOT NULL,
    CONSTRAINT chk_bonsum CHECK ((length((("Bonus_Sum")::character varying(7))::text) <= 6))
);
    DROP TABLE lab."Bonus_Card";
       lab         heap    postgres    false    7    867    863    867            �            1259    33598    Client    TABLE     �  CREATE TABLE lab."Client" (
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
    DROP TABLE lab."Client";
       lab         heap    postgres    false    863    7    867    863            �            1259    33604    Contract    TABLE     �  CREATE TABLE lab."Contract" (
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
    DROP TABLE lab."Contract";
       lab         heap    postgres    false    7    867    867    867    867    859    859    867    867    867            �            1259    33607 	   Extension    TABLE     #  CREATE TABLE lab."Extension" (
    "Extension_Id" public.non_negative_integer NOT NULL,
    "Contr_Code" integer NOT NULL,
    "New_DT_Ret" timestamp without time zone NOT NULL,
    "Ext_Hours" public.non_negative_integer NOT NULL,
    "Sequence_Num" public.non_negative_integer NOT NULL
);
    DROP TABLE lab."Extension";
       lab         heap    postgres    false    867    867    867    7            �            1259    33610    Model    TABLE     M  CREATE TABLE lab."Model" (
    "Mod_Code" public.non_negative_integer NOT NULL,
    "Name" character varying(40) NOT NULL,
    "Characteristics" character varying(300) NOT NULL,
    "Description" character varying(1500) NOT NULL,
    "Market_Price" public.non_negative_integer,
    "Bail_Sum" public.non_negative_integer NOT NULL
);
    DROP TABLE lab."Model";
       lab         heap    postgres    false    867    867    867    7            �            1259    33615 	   Penalties    TABLE     �  CREATE TABLE lab."Penalties" (
    "Penalty_Code" public.non_negative_integer NOT NULL,
    "Accident_DT" timestamp(2) without time zone NOT NULL,
    "Who_Pays" character varying(2) NOT NULL,
    "Payment_Status" boolean NOT NULL,
    "Penalty_Sum" public.non_neg_money NOT NULL,
    CONSTRAINT check_who_pays CHECK ((("Who_Pays")::text = ANY (ARRAY[('Cl'::character varying)::text, ('Co'::character varying)::text, ('Ot'::character varying)::text])))
);
    DROP TABLE lab."Penalties";
       lab         heap    postgres    false    859    867    7            �            1259    33619    Price    TABLE     [  CREATE TABLE lab."Price" (
    "Mod_Code" integer NOT NULL,
    "DT_Inter_Start" timestamp(2) without time zone NOT NULL,
    "DT_Inter_End" timestamp(2) without time zone,
    "Price_One_H" public.non_negative_integer NOT NULL,
    "Price_Long_Inter" public.non_negative_integer NOT NULL,
    "Price_Code" public.non_negative_integer NOT NULL
);
    DROP TABLE lab."Price";
       lab         heap    postgres    false    867    7    867    867            �            1259    33622    Staff    TABLE       CREATE TABLE lab."Staff" (
    "Stf_Code" public.non_negative_integer NOT NULL,
    "Position" character varying(30) NOT NULL,
    "Resps" character varying(200) NOT NULL,
    "Salary" public.non_negative_integer,
    stf_name character varying NOT NULL
);
    DROP TABLE lab."Staff";
       lab         heap    postgres    false    7    867    867            �            1259    33627 	   Violation    TABLE     �   CREATE TABLE lab."Violation" (
    "Violation_Code" public.non_negative_integer NOT NULL,
    "Penalty_Code" integer,
    rtr_viol_code integer NOT NULL
);
    DROP TABLE lab."Violation";
       lab         heap    postgres    false    7    867            �            1259    33630    insurance_dict    TABLE       CREATE TABLE lab.insurance_dict (
    insur_code public.non_negative_integer NOT NULL,
    insur_price public.non_negative_integer NOT NULL,
    insure_name character varying(40) NOT NULL,
    insure_desc character varying(200) NOT NULL,
    "Mod_Code" integer NOT NULL
);
    DROP TABLE lab.insurance_dict;
       lab         heap    postgres    false    867    867    7            �            1259    33633    rtr_dict    TABLE     �   CREATE TABLE lab.rtr_dict (
    rtr_viol_code public.non_negative_integer NOT NULL,
    viol_fee public.non_neg_money NOT NULL,
    viol_type character varying(100) NOT NULL,
    viol_descript character varying(200) NOT NULL
);
    DROP TABLE lab.rtr_dict;
       lab         heap    postgres    false    867    859    7            �            1259    58013    carcount    TABLE     3   CREATE TABLE public.carcount (
    count bigint
);
    DROP TABLE public.carcount;
       public         heap    postgres    false            o          0    33587 	   Accidents 
   TABLE DATA           b   COPY lab."Accidents" ("Accident_DT", "Contr_Code", "Place", "Damage", "Cl_Is_Guilty") FROM stdin;
    lab          postgres    false    216   Qq       p          0    33590    Auto 
   TABLE DATA           �   COPY lab."Auto" ("Auto_Code", "Mod_Code", "Engine_Num", "Date_Last_TS", "Mileage", "Body_Num", "Release_Year", reg_plate, "Status") FROM stdin;
    lab          postgres    false    217   �       q          0    33594 
   Bonus_Card 
   TABLE DATA           F   COPY lab."Bonus_Card" ("BC_Code", "Cl_Code", "Bonus_Sum") FROM stdin;
    lab          postgres    false    218   ��       r          0    33598    Client 
   TABLE DATA           g   COPY lab."Client" ("Cl_Code", "Email", "Address", "Full_Name", "Passport_Data", "Tel_Num") FROM stdin;
    lab          postgres    false    219   m�       s          0    33604    Contract 
   TABLE DATA           �   COPY lab."Contract" ("Contr_Code", "Act_Transf_Client", "Act_Transf_Company", "Rent_Price", "DT_Contract", "DT_Car_Transf_To_Cl", "Factual_DT_Ret", "Late_Fee", "Ret_Mark", "Cl_Code", "Stf_Code", "Auto_Code", rent_time) FROM stdin;
    lab          postgres    false    220   �       t          0    33607 	   Extension 
   TABLE DATA           k   COPY lab."Extension" ("Extension_Id", "Contr_Code", "New_DT_Ret", "Ext_Hours", "Sequence_Num") FROM stdin;
    lab          postgres    false    221   r�       u          0    33610    Model 
   TABLE DATA           p   COPY lab."Model" ("Mod_Code", "Name", "Characteristics", "Description", "Market_Price", "Bail_Sum") FROM stdin;
    lab          postgres    false    222   Ԓ       v          0    33615 	   Penalties 
   TABLE DATA           n   COPY lab."Penalties" ("Penalty_Code", "Accident_DT", "Who_Pays", "Payment_Status", "Penalty_Sum") FROM stdin;
    lab          postgres    false    223   �       w          0    33619    Price 
   TABLE DATA           }   COPY lab."Price" ("Mod_Code", "DT_Inter_Start", "DT_Inter_End", "Price_One_H", "Price_Long_Inter", "Price_Code") FROM stdin;
    lab          postgres    false    224   z�       x          0    33622    Staff 
   TABLE DATA           S   COPY lab."Staff" ("Stf_Code", "Position", "Resps", "Salary", stf_name) FROM stdin;
    lab          postgres    false    225   ��       y          0    33627 	   Violation 
   TABLE DATA           S   COPY lab."Violation" ("Violation_Code", "Penalty_Code", rtr_viol_code) FROM stdin;
    lab          postgres    false    226   ��       z          0    33630    insurance_dict 
   TABLE DATA           d   COPY lab.insurance_dict (insur_code, insur_price, insure_name, insure_desc, "Mod_Code") FROM stdin;
    lab          postgres    false    227   ��       {          0    33633    rtr_dict 
   TABLE DATA           R   COPY lab.rtr_dict (rtr_viol_code, viol_fee, viol_type, viol_descript) FROM stdin;
    lab          postgres    false    228   ��       |          0    58013    carcount 
   TABLE DATA           )   COPY public.carcount (count) FROM stdin;
    public          postgres    false    229   ;�       �           2606    33637    Accidents Accidents_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY lab."Accidents"
    ADD CONSTRAINT "Accidents_pkey" PRIMARY KEY ("Accident_DT");
 C   ALTER TABLE ONLY lab."Accidents" DROP CONSTRAINT "Accidents_pkey";
       lab            postgres    false    216            �           2606    33639    Auto Auto_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY lab."Auto"
    ADD CONSTRAINT "Auto_pkey" PRIMARY KEY ("Auto_Code");
 9   ALTER TABLE ONLY lab."Auto" DROP CONSTRAINT "Auto_pkey";
       lab            postgres    false    217            �           2606    33641    Bonus_Card Bonus_Card_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY lab."Bonus_Card"
    ADD CONSTRAINT "Bonus_Card_pkey" PRIMARY KEY ("BC_Code");
 E   ALTER TABLE ONLY lab."Bonus_Card" DROP CONSTRAINT "Bonus_Card_pkey";
       lab            postgres    false    218            �           2606    33643    Client Client_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT "Client_pkey" PRIMARY KEY ("Cl_Code");
 =   ALTER TABLE ONLY lab."Client" DROP CONSTRAINT "Client_pkey";
       lab            postgres    false    219            �           2606    33645    Contract Contract_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Contract_pkey" PRIMARY KEY ("Contr_Code");
 A   ALTER TABLE ONLY lab."Contract" DROP CONSTRAINT "Contract_pkey";
       lab            postgres    false    220            �           2606    33647    Extension Extension_pkey 
   CONSTRAINT     c   ALTER TABLE ONLY lab."Extension"
    ADD CONSTRAINT "Extension_pkey" PRIMARY KEY ("Extension_Id");
 C   ALTER TABLE ONLY lab."Extension" DROP CONSTRAINT "Extension_pkey";
       lab            postgres    false    221            �           2606    33649    Model Model_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY lab."Model"
    ADD CONSTRAINT "Model_pkey" PRIMARY KEY ("Mod_Code");
 ;   ALTER TABLE ONLY lab."Model" DROP CONSTRAINT "Model_pkey";
       lab            postgres    false    222            �           2606    33651    Penalties Penalties_pkey 
   CONSTRAINT     c   ALTER TABLE ONLY lab."Penalties"
    ADD CONSTRAINT "Penalties_pkey" PRIMARY KEY ("Penalty_Code");
 C   ALTER TABLE ONLY lab."Penalties" DROP CONSTRAINT "Penalties_pkey";
       lab            postgres    false    223            �           2606    33653    Price Price_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY lab."Price"
    ADD CONSTRAINT "Price_pkey" PRIMARY KEY ("Price_Code");
 ;   ALTER TABLE ONLY lab."Price" DROP CONSTRAINT "Price_pkey";
       lab            postgres    false    224            �           2606    33655    Staff Staff_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY lab."Staff"
    ADD CONSTRAINT "Staff_pkey" PRIMARY KEY ("Stf_Code");
 ;   ALTER TABLE ONLY lab."Staff" DROP CONSTRAINT "Staff_pkey";
       lab            postgres    false    225            �           2606    33657    Violation Violation_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY lab."Violation"
    ADD CONSTRAINT "Violation_pkey" PRIMARY KEY ("Violation_Code");
 C   ALTER TABLE ONLY lab."Violation" DROP CONSTRAINT "Violation_pkey";
       lab            postgres    false    226            �           2606    33659 "   insurance_dict insurance_dict_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY lab.insurance_dict
    ADD CONSTRAINT insurance_dict_pkey PRIMARY KEY (insur_code);
 I   ALTER TABLE ONLY lab.insurance_dict DROP CONSTRAINT insurance_dict_pkey;
       lab            postgres    false    227            �           2606    33661    rtr_dict rtr_dict_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY lab.rtr_dict
    ADD CONSTRAINT rtr_dict_pkey PRIMARY KEY (rtr_viol_code);
 =   ALTER TABLE ONLY lab.rtr_dict DROP CONSTRAINT rtr_dict_pkey;
       lab            postgres    false    228            �           2606    33663    Client unq_email 
   CONSTRAINT     M   ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT unq_email UNIQUE ("Email");
 9   ALTER TABLE ONLY lab."Client" DROP CONSTRAINT unq_email;
       lab            postgres    false    219            �           2606    33665    Client unq_psprt 
   CONSTRAINT     U   ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT unq_psprt UNIQUE ("Passport_Data");
 9   ALTER TABLE ONLY lab."Client" DROP CONSTRAINT unq_psprt;
       lab            postgres    false    219            �           2606    33667    Client unq_telnum 
   CONSTRAINT     P   ALTER TABLE ONLY lab."Client"
    ADD CONSTRAINT unq_telnum UNIQUE ("Tel_Num");
 :   ALTER TABLE ONLY lab."Client" DROP CONSTRAINT unq_telnum;
       lab            postgres    false    219            �           2620    66194    Contract late_fee_trigger    TRIGGER     z   CREATE TRIGGER late_fee_trigger AFTER UPDATE ON lab."Contract" FOR EACH ROW EXECUTE FUNCTION public.calculate_late_fee();
 1   DROP TRIGGER late_fee_trigger ON lab."Contract";
       lab          postgres    false    220    246            �           2606    33668    Penalties Accident_DT    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Penalties"
    ADD CONSTRAINT "Accident_DT" FOREIGN KEY ("Accident_DT") REFERENCES lab."Accidents"("Accident_DT") NOT VALID;
 @   ALTER TABLE ONLY lab."Penalties" DROP CONSTRAINT "Accident_DT";
       lab          postgres    false    216    3253    223            �           2606    33673    Contract Auto_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Auto_Code" FOREIGN KEY ("Auto_Code") REFERENCES lab."Auto"("Auto_Code") NOT VALID;
 =   ALTER TABLE ONLY lab."Contract" DROP CONSTRAINT "Auto_Code";
       lab          postgres    false    3255    220    217            �           2606    33678    Bonus_Card Cl_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Bonus_Card"
    ADD CONSTRAINT "Cl_Code" FOREIGN KEY ("Cl_Code") REFERENCES lab."Client"("Cl_Code") NOT VALID;
 =   ALTER TABLE ONLY lab."Bonus_Card" DROP CONSTRAINT "Cl_Code";
       lab          postgres    false    3259    219    218            �           2606    33683    Contract Cl_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Cl_Code" FOREIGN KEY ("Cl_Code") REFERENCES lab."Client"("Cl_Code") NOT VALID;
 ;   ALTER TABLE ONLY lab."Contract" DROP CONSTRAINT "Cl_Code";
       lab          postgres    false    220    3259    219            �           2606    33688    Extension Contr_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Extension"
    ADD CONSTRAINT "Contr_Code" FOREIGN KEY ("Contr_Code") REFERENCES lab."Contract"("Contr_Code") NOT VALID;
 ?   ALTER TABLE ONLY lab."Extension" DROP CONSTRAINT "Contr_Code";
       lab          postgres    false    221    3267    220            �           2606    33693    Accidents Contr_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Accidents"
    ADD CONSTRAINT "Contr_Code" FOREIGN KEY ("Contr_Code") REFERENCES lab."Contract"("Contr_Code") NOT VALID;
 ?   ALTER TABLE ONLY lab."Accidents" DROP CONSTRAINT "Contr_Code";
       lab          postgres    false    3267    216    220            �           2606    33698    Price Mod_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Price"
    ADD CONSTRAINT "Mod_Code" FOREIGN KEY ("Mod_Code") REFERENCES lab."Model"("Mod_Code") NOT VALID;
 9   ALTER TABLE ONLY lab."Price" DROP CONSTRAINT "Mod_Code";
       lab          postgres    false    222    224    3271            �           2606    33703    Auto Mod_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Auto"
    ADD CONSTRAINT "Mod_Code" FOREIGN KEY ("Mod_Code") REFERENCES lab."Model"("Mod_Code") NOT VALID;
 8   ALTER TABLE ONLY lab."Auto" DROP CONSTRAINT "Mod_Code";
       lab          postgres    false    222    3271    217            �           2606    33708    insurance_dict Mod_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab.insurance_dict
    ADD CONSTRAINT "Mod_Code" FOREIGN KEY ("Mod_Code") REFERENCES lab."Model"("Mod_Code") NOT VALID;
 @   ALTER TABLE ONLY lab.insurance_dict DROP CONSTRAINT "Mod_Code";
       lab          postgres    false    227    3271    222            �           2606    33713    Violation Penalty_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Violation"
    ADD CONSTRAINT "Penalty_Code" FOREIGN KEY ("Penalty_Code") REFERENCES lab."Penalties"("Penalty_Code") NOT VALID;
 A   ALTER TABLE ONLY lab."Violation" DROP CONSTRAINT "Penalty_Code";
       lab          postgres    false    226    3273    223            �           2606    33718    Contract Stf_Code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Contract"
    ADD CONSTRAINT "Stf_Code" FOREIGN KEY ("Stf_Code") REFERENCES lab."Staff"("Stf_Code") NOT VALID;
 <   ALTER TABLE ONLY lab."Contract" DROP CONSTRAINT "Stf_Code";
       lab          postgres    false    220    3277    225            �           2606    33723    Violation rtr_viol_code    FK CONSTRAINT     �   ALTER TABLE ONLY lab."Violation"
    ADD CONSTRAINT rtr_viol_code FOREIGN KEY (rtr_viol_code) REFERENCES lab.rtr_dict(rtr_viol_code) NOT VALID;
 @   ALTER TABLE ONLY lab."Violation" DROP CONSTRAINT rtr_viol_code;
       lab          postgres    false    226    3283    228            o   �  x��\�n,�]����|?zg�*�8�ldi��+��u��OU��~���0���C��:U%%���N�A�Q�Q����?7���t�:������q�����������v�_�;O����~xx�������u��3�������������%d��p���E>���||�?�Ǉ_Χ��g��8��������r�9���rq�q�������~�{�����xx{9���]�|����n�䝀� �(�($�B��o�ϯ���/����z����}���s�:�����M_W�v�ϓ~���{���u���q���u��o���q��l��ϯ��<ΝЃ�h����~~�q��'�Pv��C�ؘ��G��.�p���\)ݦՕ�O�O���?U�J6���]Շ�.������}ܝ�H�aT*}��_��������������L��9jU~��9�[��i
3;J`]zy�',#^ȡ�
�ƕp���D�b���h^�!��v�)EHqP�є�����͝t�r�A6����J��4w�����1Gx�O2��o����ӷ�{6�>y �¸E���������|
�AF�D��m�ĺ��=_ߟ�hy�e25bԐO��ZEZ��ٚb�l���,�\u�Hc�H�$����`�w*7(�փ	�BY�p��ސ����e#�>�e��� 1���JJ���~�c�7�9kzTrC�/Ǉ���;tsD7��aE�۸e��ؘ2�$X��@X�QF�����]�v~$)(k@ڋ�� ��-�җ���3H��*{k�۸��	� ������`��6s�kgTȪD��"#��U�XW`3�E�;q��:�챾K+ѐDc����U�^,o�v���
�� �R<85O!K����� �k��Y�����)�0�6���!ɪ�_�O��{�1i7O1n�TN�S�g���/�5B�*��7P3�~�j�������
�? 	L�4��.�9�&|�ȕ�J.W�������DSR������-&~�Gd�\�V��� ,��/����͐Ķ�H؀n
��|�<��#U�T#��U#$��D6�Q�k\F[��V��@�z�FW����U����"�m,LmM��B��th�f���������/D<�+$����N�Jf�+�eZAty�6�2��˭�K.�	) ���#��<����G.~=R��Ӗ5f���� �*_�I#��Sl�'�XV_
Y�. ���2���1� ��Ruɥ#�J�N��4�U�Ssϗ���5�`c�PFp�i]5@�< ��2��_����F�O���5�%i�~�����{����$�T,�%A��،��*W�L���R�_� T�d�Ixv"�({�蒄��aߢW8;OB1����<*G1ϕ*Nnh�ߧH��cq0�� v?>z����k@�}�-%"	h@�3���2�29��$��3�����XO�l ��������b����S"2�Y�U�/6n u�XV;`b�
k�ךAm��C� �`kU-��.�n�P�Z�j�����J��%�q.�h�Q}�tJ'��zC�3�̩��v)��(BVo5(�)J��78A�O�o֣:d2��$�"��k�a�N��n$0	t�ӊ+6��|�6͏T^� ��P�&�Vs����X�@lȂ���e�V�l}T�(�B�Wr�4ܭr�R\�w��!"���Gj檨cP5"�ĬMS���p5ɢp%�YSEM,i5��4!�@*��&�`d֏4���v5��]���eR?���R�����Ӂ=����S��8�e�-�����qK�8W|0;����*Zɾl՚�H�P��P�ڛ��|:�����E�?Uh�	��z���kE��,��b�@o�g.�Y�PY�g�}�j,�T|&rlHs�la+�&n��Q@#4z,�%^W�mn�-01v-5s`����.YU����3#����_����GP�Mf�:Fs ?Mh
Gvi���~S^e�� ^�(K����7E��&�^����N#��
��q�op�V�j@{��8����������oM�\�YovLШ��ƒ$���2fb�ͅV0X4�,Ra�����e[�C��ؘ�pe�]{+ٰ�w���@7���-e��֕�����5X�,�+m�`�$�
:�(Nיe瀗�F�C��,��7�(W ����܊]1=��P(@�5znL��X�=�J?��Q����TY��#d�~�Fʇ�JdĎU��&�.��)r��O�=1���΄�#����	�fZ?�>�~a��``��%�ӻY�gN��d��^���j�"j����M��?�h����KI��_�*�J�P�f�$N���q�Q.�����G�+��w��N4s�Lg�B.�~�4���n���el�I�Ӱ��6���N� 2M�G��Wc4]Da���4�/c������Sy+4 #PU�Pr��b���54���W)M-�*,:��V�$?������/[v(r���<���|�R�6�d`E��#�)�3ߩ�u	��ˤ���Y�������q���YB�pfo��Y���#I'����|B�F'UW�A �"��=��]�!H�|FA7�j��\ߘ���E
��؂��v��y��pO��t���cU�묩2!�B)ہ/ū3v�

��*61=U�YvM�M;.��op�,���׌��"�Ǿq
_��d�Cт��I_��z�#�by������KyX�M�L0��ұ��X��}��EJ�b��2�C�w䶨(�.cS�恟E�cZ0���O_
mּq�?�4�� �Q{�@�̃`����T�5IJ���^���BE���]�[ۯ��_5�YVgg��:�pCPـ���G��p")��vR"�5$��4%\�}��x7u��%\GSn	�Y��HQ]Don/	��1��J�^���-8Q��R���Q^��.6�����RC��G���ܲ����"1K��g��.7��h�gv6����~9�\��T�ZjHvX�U�t���H+P?Im�)i�5�)��L�S�@ᬩ,s�R�x@_���>idP��o'����T���"�K̨�5e�vE!��(�B��Q:����,�0/a�,ʐ�N�k�h�L1�3eXP�6�f�E��L��U����c�Bv�����+*��K�ʛ�t
�M�R��R�[�i&e���+W�RAEXZ7a�h�7*h���V�c!;�}lI3�(�`�q9��!�M+Ӿ�*���Bn���CZ��TeK"���+�^�����
1RÃ�)���͝3�4: ��[���}9��h����^Ի�,�W�h����&���f�-d��CdY����>N6W�,Et�F+2�?�4W�0(:Δ�#�kK7O��PO���	_ꓝ-�jc4U�����6־��ߞI�Ri�CΗֶ�3���tN劦�lD�ĭ�i��c�O�(vK�l+�ZR�<��������=��T�'碕QY��/,ܰ����e���ٷ�ݟ�o%ʩ�G�E��`@V�����i��4	n�>�2	���3����i�O�_K!��ܺJ������Ee����ٿ~�&0����x������	���6�L��vG;6����	��(�ֳ�3���эY5����; I����hLwwj�Cw��_�>�х�F�R;]�t�?}������q      p   �  x�uV]��H~Ƨ������[���'�#�}�	r�h�}��R�h�Ñ���3^k4�0���栗@��Y�Y2��rd24����|~�Z��RĢ�Hw�l�X�Z��'(�-dbWuu&�!�&�w8k�RU�>�wq�m��Ȩp �ِ�4�~s���s�g�B�>�W�R�v�F?F��K \���[�D�$4u�r@;ܘ���p�!����#5���$�6Y�s���+�3�u���&��#�1�S�&F�ܭ6`Ċ�&o �R'��@�<�l@T���r�v���wH�����>DX45���:�%yq6��V�g�$Gp�F'�b�e6:��.����*�*�0�Ud��T1�!T��.���&�\�����h�51""�"e�m	��IN�D��5�3��$'=X^��M[���*����ɢ&��ӊ��<-u�2��4�z�wFy�`&�gC��9����q�,W�n�]r��]����t�S�^��T �@���D{�	,��h¬@A�x��)�>:Փ�R2�+���f��9�|W���n�:;UkI�#1�#o���#jY��y3	�f��S=���A���n�uv�6�7��<?�ݍ=�"y܎���T�i��asAb&=5��j��IYz�'�z���v�;qJ�'���XJV�z�g��|���j��x"{��4az�x�I`��6���g�nԳ�jwi��"R��e���`=��Fé�����9[Ƴ̷ >�O;�s��L�X��z�2e�=�ݧ(�^z��b�kJ{�jR���%^���y��M��{u�ϵ-�]N|��o�/p��	IR�K!a^�%"��?��z����x�U���!������M�(�u�\�)u�̹PM#lb��ו1l���V�.̨)�^���P(�V��b���m9M�/
ݫ�ATfO��DI��)��9��k#�'�i_(֚�D1���6�����x�{P#�����g��-t�ߣ��M>����a�'����]Е��$H���uW:ߘ��z<G���A���.#�>��̧����bZ)��z��qM��l��=��?����G���B��J�)h=���qCd�R��l;�ڠX=J�R��dY�V�OH�����v8n�#��IY�oP��ӿ)��MO�/GZ�[b���ec���[���뽋Q��ػI�_��W�F^qukJ�����,-=ς��n���7W�wim�c`��OL���X,��a,�      q   e   x�]���0г�
��.��8�9X�5�c�}�����	�B�F�Q����r)YC��V2E�g��0όf�$r���V�H֡j1��2��1������5P      r   �  x��U�n�0<�_�(��^���i�u��@/��X�E2����.)[�]�h	$���j�3�P�S�b+m���j��hm5J(#�Yv�ȵ�;�7�ȷ�5�0���Ax��E�|z��	�#�V����Ee�'������4Y:4���5����*z�F�W���^ ��֒\��3��"����4 ���Z��GN�֚+abF�(v���]��@����~���������A�I]'ĭ܈f��{�R��<��x����w6��t8�{B�����0S<ȭ�NΨ�&a���?h;�fo���(�NCY/ݗ���Ș�9��^~#��u��N6��i��+p��w_�8KiY�Y�R'qL˴��&,F��ZɨR���n�>8��x���|<��4/(�y��y�"��W�q�P�U�k-�����9��>خ�ܪ�G7� z��)��t�e�sD�Z4�h'M7j�9���]c_m�Zt�� ё/���G��l[���q:�b���1��&K�9���D�<��Y���<H�^�p�����VT�������ۻq(�D��>%JpȺ0w��l��C�u5n�g����#-���̼h��AQ�gbe��uJ�,��=�OC����x&z�}jPH�V��� <�� 0ʔ��`h��Z	���>T��c�t3��.Q8������*Bs�9���37X�Uv��^�]�}�ݟ����@��/��|�5���g�=O��!�;k`B:@�\�j����d8����D�"��G�D+ả�]�>�n|	�j��V5��>��N�ɨ��X��f�x��8��{��K�z���0�.�,����h+�Z�����.l��{�y(��d�֔ۺ�p���]e��n�Yڝk�nE�AO &��u�N�uS�F�ߞ-�c      s   V  x����m%9E��Q8��)j� &���:)�ڪ�ð�������?pV��G�0]�}| ��w�M�,ܐ��n���?ן�R.�F���Ob�H_ ��]1�� }�vSb�ܐnĩ%�.���02Q��j�"�������Wt���w7|L�}��mj�3�P�$<.���o��?�9Q�
*��������ҁC�i ��k����%��_,)S�L�G���N�r��T˒�U��;�Sp��V��P㈧9��Ab��d��{��5��м^�?��������c�eJ8����Ͷjtji~'�x��b����Ѫ!�����3t��-Ĭ��]wOp���5�N��j��������aZ��kR��K�x柦����ԏ<��R�v`�PZ��,J%+ �4��䘣����QF� ��^.����,��v��L����"7�����Q��1Ș� �-vS��qY��b�گ���#��i��N��Hh�Z��,M���)�et����Ӽe��׸6�*�i	���\L˦�{ ���i������p&);I���d�bشv���t�4oY���aʽ4�4�Zo5X�˒>�_��;fX�}�����ſ�>=�5z}���c�H3�YZ{i��ɋ�6�9�u���O�D+K��Fb�X<W�ji��x��~?��x�5�ǩI�K7�������r9����u��C����zNn����V�L�&��	�����^z�D�<�ݳ�E/U�F���a7���1!��ɢ"�2,��	ZYq��pxf!m>�kD�UE���.bf�
�e�q��i[#�hQ�l�d����� �U^9W�=L�ſ�r�o�W��eF[���lc9��/����/͛�*49��6�����x�$����i��p�>�18�6���N<é飳\�G�����c{4�3}/!��)���V��8tN?�Y�Zo�Y
�����f[�ԏ�,)/��>XG�,�g��V��H��s��/�_�O��k����-�M{q�|ؒ�ȼ�|"NlZ���k��4�۳j[�M�ܘL������׵(�F�֔&_���ޭ���Pi��R1���F[���������?��k      t   R  x�m�Mv�J�ѱ�
o@�4���Z��u<]-Qp%���A�#-�,)�?��"�Y�)�#����<�R�>�2:�=����Wc`�G�:���h�qM`>�P��X�&����D�Q}J��h��QS�	��bLT�)���A�0{j�����WU��~5&��C+��[�9�WV;
�V��V�1~�9�_\]L�s�յ��9Ǿ����F�0���LD��«Ze�AxUkLt�j���Um01!��M&�W�Eľ�/�UkaBN��ZQ����L?���U�21!�j5&D|U"�@x�ژ�Z;
�U�`� �j���)�^�.&�9�j+L�s�U;L�����ڔ	�Um�D�Um��v���V�u&ƭjL�[�6�X��m��^�&�jG�3��>�׫ve�ߪvcbܪ��ļU퍉u��;���U�`BnU�dBoU�b�nUG�#��~�U�N������U�2� ��0"^���UGeB ��hL(�W�	����G�^{W��s�:�^u&�9vչ���F�S�߉�_�Qu*«NcbBx�Y�X^u6"��y	�:;�U�`B!��n2a^u�?�\���0qα�.T�[��S�k���^]�D��˘h^uU&:�W]���UWgbBx�5�X^uM"��:D�6/&b�7F�$�/�]�N+o�^��*EQ�xu.ƈ�Ļs��TO+�1�@����H�R#��J��L�+e1�@�/��7�?`rn[�2��⛡�*m߷�i�H���&���q�����Y �W:!����H��Ɉ�D_Y�H�������K*����&�d�1�����͕��D_��D$�bu%b ���N�?�&��+�s����9K���J�%�bz%RO�����U����L0���Ǚ`}%�n�3��J��h���ȸ=�,�y{�	X"��LL�o�~tF_l�D��T��D��&Xa�+�@���߿��\̰D$�b�%b �w��
}��i �S,�}�� �c,�	}��Y �s��w����=&��iP>�7�D&H��"Kd�D_L�o�_����,��e�(H��*K�@�/fٝ����vY"�,��,�s��2����߼`C�Y"$�b�%�@�/�Y"$�b�%2@�/�Y"$�b�%�@�/�7�OIL	�BKD@�/&Z"z����h����"�~�O_��D$�b�%b �3-�
}��i �C-�}�� �S-�	}��Y �c�����/֚����s-�q�����Y���-�3��/�7yo��ɖ����-��b�/F["g�F_��;�=}1�9g�}��w]��w Gn      u      x����s�6ǟ��?�~0y�]s��$3�sz�C_X@S@Tq|����`�����Ċ�g���(_o�ȹKW�s�׼�K�����+���WW���6�K`�ӼX��B*�%Y�	Y��h�Hsh�J��ӈ-\���������=\@�ۧf�_�/�?"��2�j[�o���s� ���A�KO�o��4�=(,Y�a*dz�����}�aY#h,�^����KP-��P��u��=�p��n�[@�b���$/����bT�{��������P	IcB!�;�kr����/D���m�4vBvf�w�0��c�n�m� t~c�HK~��� E&Hk�ط�/�܈�������R-��/Ȥ���K3�O�p�q`b�Ö�N�e��d-�Q�cG��kM�xA�Q�6\G^OA{��@;W���*�f~
���O�CtVВ_�6V���[�u=E�m��TO�b�A�N�1P��Z���[���Y�:�l�5��G����Qv�s�������GD[��3@u#ykHYP��уq���I�#�nZ^/t�̄m�x7P.)���:��,!�F����	I��p{&�U$�	4��O�*����@�S�Y�����G��ؚ����2�d'	�{
 �t"���؝ d�aV�k�s��<�M��i�Z��s���F�}��\{[��y��j��y.�~�5��p����g1/�z��쁒ܐkx�x�ڌ�Ċ8����`G��U�4��*)5����|�~��I5��~���a��Y����'�Ϯ�+�_�&Ce��9�d�&�_���>KT�
�\��=�H��-��s��ep+J��ֹZ�����'MG�f�|K{n�@����To&�S*�!uT��[ �͙S��[�F_���g����H��p[F�y�Z��lI��7]F�h��,�Q�D�ߚ�Yc[ �����S?�{��Ǩ���4�\D�8�S�i���7�]Bg�|�1�i��ղ�D7P�t��/�}*V3}�l�6d)�ݿ|�u�,@�      v   �  x�}X;�cG�gN���o^���p����l���Z��B���*�b�!�'��Av�_�����co�?�1��4�<���%cǨI�}����R��1.�#�"���O���e�����M��!��et���"K�j���@������>3�K=DP��k��k���;��)z�\�8;'o����X���.�v����T��E���dj��)���f���Y���ڌ<R��#����j��՗<(��`BwwI���Ȣw@���wem|��[=� ƨ��Sڈo��� �C4bN�i�0�3bf�E ��Pn@�etE�׸t:��>�EŁ�HV,���+��6P�Ю&ؚ�TT�1�֡��bd��-���u�N�h�:��U]���b�ЙO��\ 4mt|z��c� �C��'cJ5�.^LP�E�����Ѻ��z�ރt���blM���rbjd����F!�y��dY��t�ĺ��bm�q�Gs�{�YR�KR��	@����ਔtv��a����$Y��0D��Ud�P �V��@�w�sy��ߎz�qG�#��#�B��k��(�r�<<�[K�,�yt�)ۂ�@��h6��WM:���,��<k��@�ѭLb�^Ӈ�j�<��f����<�:���2��@�_��J:�o�&;�+	5+p$$D��+����1/"�
a����5�ݭ����@��UW�ơA+%����\�`h�c�0~���U/ W�D�1Xa_Rz��m9U'�v)���[��[�����m�{�(s��A�� B=���)Zw�=�9|cs;���Q�A��a�S�%w�6#��eb�	�D�x��e���Z�[��ϗA�=��FbaCZ���e�	_���F��M�˗)�"�P�G�m4�P;�"\�c������C�]_�C`H�Ֆt�*�)������~�q�0�Q
S��~`��y�uxw,�~|��
������G=eA��j�Z[iP��M;���w9s<,Wɠ��X��9�R�XI�C��z3`8�b��<�366jz������RsH5��8[��N��l�g�5��l�!��Jtv[�B�o(���1F)5-,|[��T�p,Z/5��0x
�+�@i�5�m>[��k���?�?�`%���ɯ�9��pMl�rf�����9��&����+�XH_�4�{���rdl��=�p�Qx����i99��������ڲ��8�f��[wm��x��7���`}��P!�[��O�^8���l4r�/z]n.ʚ�a�F�?޾9�Q���%�f�S�d����(�m-}{yoCp��5<�/O��e(y����'�&v���,ɧb�#ibcǊ\�1<t���~8�(���=�o_���O�o���Bg��ِ����g	�bǦ�J��_�`
�R���%t��Ϗ�]^!ǖ�
8`�FP�\˿�Ƕ(p|Ƨ�=��N���M#�92��)7���]�92<_
|�Ӯ�X� #�zk_�[P�.L�}#�� !^.��~��W��6�8���"D�$����P��1Čbx����<t��aH+�k�j��w����%R攽�[4��g������eq�~�i	>�������~�bw�Z�W�s1ir*��q��)f��w|S>�j������2�      w      x���ˑ�H�E���hz���(!F��_�AD.��E�a���"+�H:��;�l���j�����f��������������W�������>������Z?�=�j����鿾���맥�~j���������K�����:��������z�t�?~����_=��?7[�fw�����;�ߞ�W=��~���o�����~����y����7�c	�/����|�z�]���_������o�ߥ����M��|�Z�f�U�����m���n�����m�^��.{���o���տ�z���.z;/�v�����o�1�����|��=������o��x?��y��vq�q�����o?�a�V�e�}�y�������s���X��k��Kv�d��;�%��>kp��}ٷ�񻟿�������k��z�������sh�l����~�.{���o?�M�e�=���]n������ڿ{��+_g? /�z�����V?ϡ��{c_�����o?���,��z�����߽����/�Q.;n������~�#���u���{�e��8�����e_���~����_�ն^޲�.{���o���r�����w?*뮇R�lK-���J�q�]�w}�{�Ի���j������N��~���5w��n��~��|;����w�/�����#;�_�+_���ug�d��W6���J_���+��{�9���z��]�w}u^��}��d��Wۯ{޺��]��+�z_�ԓ�ﲿ뫗{q�k�m�d��W�7l�e�W��y�Ͼ]��w�ʏ_=o�c�.���ʳ`�&����]0Ko�;}�=i��e��W�V.t��]_I?[i7�o�+�Gk��l��~���y�z?�����\ݴ�:�V�]�w}�Ǡ���]7�o�U�g+�h�+}%�`��e��>A���]�w}e������_O�u�Zﲿ�+�_��}����}U�]�w}����^Ɏ���J6�������۲�V�}����<������{[=7�/��_�������������V뫼�V�_ă����u��d��W���_d��Wy�۸����RǶy��]_��k�&���r[��:��K��;�Jg�����*�kv��"�Z�r��B_)��^ﲿ�+�9�/��;}%?�z��~�_i����~��k?�<�_ă�7�e_}��d����~�_E�����~��R�w�T�w�j���ڰQ�_�W�'�˯�Q�_�+���n�_�+�6.����U��1�_��3ؘw�/���5l�������%�����wt��:�]��*bv��&�M�J�hֻ���J���}���J]7�]��9n��ă��s�e��u��e_}���.�}��"��<�M�}uy^K8�������*w���U�f��e�W���|���d��d�V��~�o�?l�e�]�����w���՛ʌ��^�&���J�����|�pϛ>wY.�����2Yp#V�%���w��~jS��Ƃ	w��.�������C��M���0�j�eWX���e_}��L�}��BaP�}n��$��Fa�������X9*�>ʑ=f`v0 T����/��ԓ�|�����f�cg
��a@���8 ��r@��5Lsc&��I2Lcs�R0!��e1!�ಘN?��o�e1!��rYLÈ��cB貘^�rwYL� �,'���?f���Z�Ǆ�e1!�=Y1!�u��F�ಘF��e1!��3&��Ⱥ,'���0���%��@�,'��L��bB��qB�qt\�MqYL��ń0���bB�{�aB���rB���F�ಘF��e1!��eB�}L]�����9��=sB���,&��,��A(!̽10!L}50!��;0!��N\´e��W��U&��{Ƅ��~1!̳01!L�?1!처F2�e1!�381!��3&��''&�y�''��E'&�y'&�iS&��,pYL�x�,&������ �.�	�b��	a���H��,&��s&��~7&�y7&���bB���Ƅ0�8sYN��B%�\#�<�#�L�l�s�0"Lكa*��a�+�ň0��bD�ɂ�aH#�&&��UuYL/��t&��&����@�.�	a*JÄ0��aB�
�0!��aB���0!L��0!L��0!T��55%�zG�<&�.�	��`B('�N��ׂ	a|�*���cB貜�~���8��rB���.�	��Z1!TB�VL�Ԋ	a�ߊ	a�����Q�ʯ��B�߆a|��*���;�)�KÆ��Ea�߆�I�a@(�6e�k�0|`��( ̵꼄P�c@x�����b@�g�?.!tYSot^B(�9 �x�v����l��%�ړB��u`@�tƧ�.�a|e���*���B����l�x��%��	'�JB����jb@��nr@��09 ��o�B���%���B��Ke��-^B(��x	�t���Sv��.S�.^B([�0 ��ua@��u]*�Y��B�ŀ0��vY3������n��6�y~7����0r�uc@�{�p@�D}Wc@(?��B��a�F����`@%u.�aƒ��O�/!�Z���VÀ0��8 Ծ23�4��������O惺�b�e�?R>�|�?�ዶ����W�����Z�|�"�+���ί�u�Z�|P�U�eC=��|P�F���.�%�|P�~���ި�j?W��V�e�C�|P~]��F��;��A�V�a>(���'[�|P���#v�H����P�5��o��J�瀰5�v�,hB9�bQ@(h�:�zG�������P��c@(���$\A(��y��|G�Ǩ����ړ�Wʨ��n��H"����68 LY�c4�68 ��b@��a`@(H�&�J��+#0k����51 ��m�
�Pgb@��hb@���MT�Ā0�wa@xq&�i�/!�aX�^�<��7��^�*�[�f4�8!��Z��1ۜ��L���*C�����&�B��Ƅ0=��	aFu�t6&���6&���rB(�}7uYL�x^B_a��	aF��t�/!�cw��vx�QuB}��&��s�ܓ�	��${^B��q�Q��MF�`&���0!�����f�fV�0!T@�o26�N#[�o2��^B��G߸�0��`B��]/����'��eP/�����	a�ߊ	��~��Ɨ�bB(��WLu~{ńP�Y���+�^y�Q��	a���bB(b�+� ���&���ƛ���7L�?��+C���	�E����zÄP�do��0X��q���{��:��WJ�u^A���1!���
���{�0�����{�=F#.���W�Bم�	a��>0!T���sB�&����
¼.B�}50!L?vp@���a�V}`@�8�^A(?gr@��<ya�rh\A(�31 -��L��	���}>o2���v�������x���������0P_^�����猰/��aQ_�*U躇2Bq�8#L�7f�i�7f�i��9�.�x��bF��hcFx��]Fe
7g�R3�Tv�3B��a�VF��~/"T�}��Ë�^���0�9#�3�ț��x��a�gƫ��"��b��CK7�ӗ5�Ө�"�{�0e1#L�e�jO�a��P��f4�d3Bq�Q� �ptF��Pi��p��DG��PFe�e�F�0�䨜���"��0*D�訜��3B��Q1#�C��WFneT��7*D(�S� B�߆a:�aH�/�qHFt4	#�3��JB�����ACB�ޣ�>�a�G�0���aH��)F�e���!�6t������!�>.��� w	/k�!aD��2B)��!��w�6�����0��!���c`H(�8��Y	E�����xa�c�2B�Ɂ!a:vCB}x2&���)��*`���0���;�|ad
��mF#5&D(    �;� �\+	������X�YX��.	�7/#���0$L�a=��caHx�.��y�����CB��1$�{��߾��C��6f���6f���6F��ol�fTgcD�0���0u���0㲃a��ë�^E�d���0���seS��9�nX0!TB�pB�"����r&�YLS�&���n'�����ƫeBa�a���l�*f�B��,��u1!��B��Y�g�s���,��h�f��P��,frsV>�0��|a(?M��0Hά�ʈΊ	���Y1!�.4G�Q
8+F��
g�e�ڕ#¼n�02��aD(�{6^F�m6���g�e�Z���F�>F�y/#�vo��hxгaD���I�R:�#� 9��2��
g�#�#�f�FS�y���w6;F����2���́a>��e�:�BE�spB����P{c`Bx�.&���&�y��F��SB����3J��tL	a���e�yϘf�1y�Q���	��yy����P:g�A�:�7�R�Ǆp.>�0����ӑ�0!L��8!��\��>�����X�*�3&�y/#��ݼѨ�jcB�A��e��)���F�rnL��ߘ��ۘ�˂�9!Ծژ�߾y�t��P��`B�I��	a���	��}�(=.#��"T�<'��`BxYgL��^F(�x�ޑ�>�����N�0H�4L3f7L3e���/"��7�gT{�� ��yL�E�*�*ɸ��>��`B���
'��q_��F�}NÏ]��ؓ��q�ш%W��P�}��}FW�5��o��k����	a�G�bB�g��� W�bBxY+^C>᪘J_��	a���aB�x��5��aB���j�F��j�F<�o3���0!L]�0!ԗ��=o3�&��';/!�~�ʯ��%��Ǯ�J?w�f4�u��B�Ў�`����tN��3t��^�A�5� B����`�����l���#o��	���}Fs�0 Le7x����0zb@xY��	���5�7]B}˸&E(�rrB(�2��51!L�a�"� 9k�"ByX��(µ0!�u^��\|��0#��	���0�����=?o4��!���1!���1!�(����¼�P
ksD(��1"�'IkcD(��6G�ru6�4���y�B��;�FJv�iT�Ë��iTF�pD���N��χ#B����R���"B�8�E(��xa �eϋ�aD��kj��#BQ�E�r8�w��5�iT��=G�˞w݅�"���.�w�0��.|a����)"��#BEW�`D(�F�j���4N�.|��U�E��P��P����ؕ#�p�wňP�ʮ��h��]1"TjW�/���+�E�r7����3�T�3�p�w�0rлaF�|�n���o�*��3B�ݞ��3�˦��h$Gw��プ�yax���F����·J�v	SSv^F���1$L-�1$L��y�шT���P^���0x�ш���eo4��;0$L=0$LotpH��!�2{�>����C�<��"�ٟ��P^��}F��r�����`kO>�0�CBe���E�2�C�\��|�^|��yqHّ�x�Q9�j��	�0��07���s�0$T�oo	�U�ޘ��ۘ*���sF�7f����a�y]�eD7�"��9#����~^E�g�R�y�>�fTw0#��{0#���`F�i������U�23�=*�2	s�C����7�O�aF���0#��o4_�l�e��3f��lt/#��0��E��PF��h4��S0#Ծ:3BE��`F��p
g���O��#uv
o4���jO�����~*f����T���>�7��V���:�yᩜS9�7�l����?����٩�Ѩ���2B]��i�aSNÌP%L��2°��PF(&z/#���4�S�5���7�S�7^FA�������F�����t��G:�3��"���e�1#�w'�cF���sD��3x�����# >#����E����P�h�2�Ȫ����y1"L]70"L_e`D�zcbB��lbB�zrrB��?1!̽1ya��31!�\���Ą0���F#	u&&��o,^F(]�8!�-[���.>�0�PgaB�	��x���A*gaD�kqD���gaD��ݼѨ�wcDxyI3BeV�慄����F��l�Ӄ޼Ѩ<������|�"��	�·3BeGg���aj�������>�PV��Y����#By��7U���Y��g�F!{�h�G��ێaDxy^�h4��y�1>�P^��2Be��7�!4��'�`D��r1\FQ�^F��h4�3+��hd��Q�����Q�Z�0�����
&���Y��'+'�[ń0�3���h>0�E_[ňP��*�E��*F�r
��2�\���F�2*�x��]ÈPN���F�aD(�c#�T:�#B����#e��F��/#��v����cD� �:/#��v��[�0��ʨt^F�u��u^F��:F���G�:�#��l�Y�Q�m�#��
�N��I��s?��Fm�N��͙����ӑ�F��&F�JB�|�mbD�d�M>�P�j�N��)��a�3�4*=99"Ծ�|��j�*BH�#�H���P{r�Y�:�#��E�"��_��P��P�a�!��0���Fu�#´ݛw�-ۼӨ����E��"�Ϸl�"B�)�w�ݼ�Pv�"B�W#´)�j�F��c/"��p0"�\�w�;:��P���N��S&����i4�vx�Q�Ä0Ͼ�"B�{>���<����/"�O8�0 ��#3�h��P��x�''�J��0���b@���"���~|3�ŀ0t��b@9
��?>��r@��1.��~Α���\���O��e��,�3�9�.�'joTso�ǀ�eya�3���tY^C��_y�j.�x�ǖ�,��'���,��'��Ϙ]���b@���r@�ϋa꜆a��U:�D���\���]�����ͨt{�mF�y�Ѽ.����jOv�u:��p��ی�v��g��/겘�Y�'�,�y]�/��K?���|0���|0�*��~�.�'j�&�D�a�.�K?�g��|08��r>�ə�,惗w��`�������,惹V���~^�ͨ���|0�_��mF�/^B(��0����r>��X�e1�i.��`�]��j�6��=��r>�)QqY�ӟܘ��߼�P����`�Ƹ,o3*��y�Q�8�O"��	]�O"�0�U��o�����|�e1L�<�.����|�|�û�*7r�$B髃�`�7�7�=2���6��G2�󺼄P��8T|d�*�g|����I�ғƛ�~�+X�`>(�^烑���A}���jSւ�X�`@�MY��B�ŀ�r]�e4V-��0���>�2�*��Q!�
jŀP
�V^A��ŀ0`���Q��֊�e�1 T�_+�yE�]m^�NÄ0_p��2x́K�NԆ	�2�aB���c;J�׆	��:����1!������U���BY�������˨�bB���cB�l_��~0hL�KW�J�Lӈ�eT�w`B��w`B�zr�.�zG��|^L����� ^B��<y	�l��%�:��B��+�NN��'&���ubB���Ą0m�Ą0���	���	�����r�D�u^��P:gaB��yaB��]]�J�-L��Z�ń�"�	��ycB���͛�F��=CJ3��|���Ƅ0�؍	a�H�9!��"�Q7&���6� R绋Be�����)t�D	�R=��vL�W9��P6�`B�1�y<��e1!�W��
����� �92L�y,o2*�o��P>�aBxY�焰o2�8Ԟ�j��0lh+��h�:����0���B�*��9��qϐ¨�tY^Az�^A��7��;�O���0tl������1�k��	a�}ߙ�    �h>/C�~���h��:&�a�ZńP����d4lY���P:�aB(��o2�w�x��`ÀP>�_��B���ғ�[����Na�����UǀP�w���*�lB}������[�F��u�bT�c@���c@���u^B����{���/!�Da�u9 �����.�Ks�y��H������{,^6�x<�p��	aZ��	a���	�,�Ą0���	an��	�,�Ą�V�ɨ6�Ą0���	aj���ɨ�bBx9#�<�#B��#�t�F��)F���F�iFF�Y��Vm#�ܔ#�t�6�C��m^D(%�9"Th�ya|l�6F�����E�m?/"l�y�o.��y�sD�F�J_���J_��E���9�2�#��=sD��}�d�e9"Ԟ4�dT�È0���9���Ƌ��#B�W�a�g�MF#�݌#B�{^D،�Y�7��G�������7�� F��_�#���9�.ˋ�3�^xa|��G������a��&��-�#BE��rDH�W���ʛ��M�#z}�{ňP>�oj��f���6�æ�ƛ�z��=�9�������o�Pg��&�y]�����!�:w>�0|��y�Ѱ��cD�{�?�C��M�*���ZaD�z�cD(߻�爰��E�}`D�{cpD(�08"�ت��G�]����,C����G����a���k#o�'�!���O�3֘����ɨ���S��>y�Q�����h_��0r}}aB���z^B�&�y�o2�xaaB�gaB��}qB�8eaB����Su7�z�ͧ*�
z��aڲ����o#����K��͛��u1 �}�1 L=y8 T��`@�q��MF���{��D��|0���%��	e?�^�惙�<�ɨ�P�|�"��`����`�ކ�`�6�����A���a>�z��B�t��`�n�|P:v��V�`>(3
�ᛍ�p>�0b�Qx	a�
F�|P>�(��=�A��G�|0�o�%��_��K���AٔQ���ʛ���A�}�?\B��[������`��s?7^B>�h�ɨ�~�|0��h��j|a���a>�������x�t�Ss�0 �C�1 T�at�e4����h���ya|�3:�2���1 T"xt���¼��pt�eT�<x��D���0������1x��H�������,���b@��j`@x�g>�P�p�B9��H`����11 ��O!��21 ���	�<��	ad)�Ą�zӼ�h����}FS#B��caD��raD�a�P)��0"B��!LY��.>�0�_cqD(�n�6��6�"Ԟ�|����0RXc?�C��u9"��1"�=�1"̐psDXd^D��q8"Ԟ<f�p8"�{ƈ0=�Ë��G�:G��!T:��.�Jq�3�7�so�!�7j^�����0>�00�0>�P);�s�*-c��0��9"��#�g��P�Yx�шTf��P�,ϻ���K#;2F��@��ی�sF�,�kg�0�Y1#�������ݬ��0�Y1#��3B}�5+�!��nV�f4��a8�bF(k6^C��m|a���qFN�l���l��0̆���8#�uƌ0�B�#U8�!�������|��F�#�0;�!�Zu� ��k������k��:f�r
gǌ�b�����C��C�Tv�CBy��O"�{�E��́a*ʁa:3BE�spF�󜼈0�Ȝ��P^��E�z��'joL�S�L��������|���Č0��ɋ�`-�#����-�Ő��P�aF����P��8#L����E�r�g��ݜjOn�gTk�y�Q9I�O"�:o��)ܼ�Pzr�>����ƈ03�FftnN LS��gTA��}Fu/"TB��A�rd�3��ˋ��Ë\LsOL/���*B9��N�U�2f���,G�J#G��	��F�ڔ��JQF����#�Ȭ����*��X�W��X#B�U0"��\#Be�W��P�c>�0��)"���f4��Uy�ֹbD� gU�#+�*F��Ε#��`��������~�JO��a��aD(;�D�p��a�sÈP�j��P�ܞ"\�y�j�꓆՞W�ƫc8�����|aW~�p�tl�#��:&�Jn��	aڔ�|�꼊0|�՟"\���D��1��50!��bB��l`B��{�.��V���	a|���2�{��	'&�*�X�y�ϻ���	a��w�ٟ|���Ą0���P���0���xaow�) �qǎ����Q!�
�� B?��:/sO.�.3�Z��0�B���y���ƀ0���/l�eTva�"��A��FimS�lE\���:�A����T]�y��ux�Q��	a��	���|^L��9���0!��3&��d4�fT�aB(j��¼g>�0(�2�fT�l��\���p'�R���.ÄPuD�`B(%�'��|��	a���BoɔjO��ی��܅O"�aL��v�mF#�B����PkU����k�Yٕ�՞�ʑ�B9g�b@��ʮ��(�]1"�vߍ7��hʚ�a������n�7�>��|�nF��c��U��aD��0v�0���*]�;F�J����JSv>�0���1"�sԟ#��1"T�aw^E����'����T��U��f�Wʳ*e�G��c���0����0����0e� �|^��N�����bSD�4Ԟ��P:v�F�ғ�#BE*�#�H��aFf��ZaD��nqD��.���ًʆ.���0"�w�x���0��0#��a�3/"T��1"Lr�"B���a����l��E��D�~>�Нw�hT��ƈ0u��0�#��W�7��D�st0"̸�<�!܇7��F�i���>���A�)�af�G���a�g�P�l��2���D(k|�l��A���#%�#B��|�+��}FOy^Cx
&��@��A��ΧpB�S0!�;:��|^>�0t�)���s
&��'O�5�)�ku�Bš��>��O��	�t������S1!��3&�y�*&���bB���i|���aBx��#.;�w��h��=BQ��0!�<��.���.�:��ԓ�y���1!L]�1!�s�y	��sǄPy��1!�}�y�Q�ߎ	����c@���s>9�3x	a��g<Dx�s>x/!����������F3�30��<0Lxp>��3� B��ɻ�Ɨng>�gb>����|0���|0��9<�9<����ɜ�F��L���/�3�\�F��,^B�Xr�A��9���p��mF�0���y�����ƀ0��a��k��6�J�ͻ�F��lsCosOn��ڼ�0�������>�>�P�{0 � �`@���9��h|Du�D(��p@(|�$���I�r�Z+�PΙq@��5���1>�Pg��$B9�'JO��|���0 L��0 �ް��ޑ�/n2�V8 �$��1 ��_L"��	��L��»�F6�
&���V1!��d�O"�ChB9�V9!G�*&���bBxYg>�0�_Vya8V9!cf��P��PB��aB���I�Ab�qB�5L/��	ad��aB����]F��I��W��� uL�@[���:&��~;&��RX�Pg�sBA�u�e4B뼆02��1!��3�2U56�B������!�d��ʆ�eT����PI|������jO^C���k#���	aڔ�	�o���ޘ�^��k�y1!L�09!�Y��^dy�� �6y�Q�߅	aڣ�	a	�ж0!��3&���.L�->�P6eaB�d�-L3�Z��Pk�9!��ݜJ�oLӏݼ�P�}cB�:gcB�d�mLӆn>�P�hcB���ƄP	w;�ɨ|�Û�� �  y� T�|x�����J`S�����;S��� T^�8 T��x��_�MF�:܌Wj��Kb��B9ƻ�jS&��)��!���.�Pv.���,&�YL�3u�ń0��bB�ɹ,&�A�\�q	��bB���bBtq�ʻ�jOVLCQ�,�2����e9!�:W�e4��p\��!�$�]�P�.�	�'䲏��n����c�\^.˻�~`�ń0׹=.!tYL/����d�0ey	�'A�|�'��K�%�:���!�|j��Zu��:��W��!�$U]���Za@	�ŀ0��ŀ0��x]�H��,/!LY#uY�vY#�����ɨ|���'xvY�Ms�'/!�O81 ���\�B��|<��e9 �$7]��l�eB��MF�N^B�	�wY���,��-^B����ey	�b��a>�c@��]��^�Z�����.�O!�Zm���c@��n����|
���ƀ0���S��6��n�^B��"�e1 L�~0 ̳px	����[����:�Ũ����0����0��O!Tle�Ũޯq@�=i��P�l��P���B�A�Se���:c@xy^�bTv���ؓ�<n1�F����1.��,�B1]-��h��ZO!tYeSj��0�o�����,� �R+�y]��+� ߬V�/��|0�F�|0�U���7sO��A���a>��,烟��\��A���+�W��WF�R�B���0�va�6���ܔB9�n�q��HՎ��n�0 ��|a8I�C0 �|��|a8еc@�����p(�x]}���1D�:.��j_^Bɾ:0 �</�	�x}��B���EQN^B�M��(!LE9y�Q��	�"�:���P���~�fr�焰NL�zOLS�N^B��0!��h@벜��.^B����º�ByXBe7��%��i�I	aFH���iؘ��ߘfԾy	���Ƅ0���K��!tYL/FecD�kcDx�ň0��5�2H�#BY��az:#r�2*�t�B��F�iD�2�(�pD(#z0"L/�0"�:"�ň0�~È0��9��r#�t(�#�s��2�e4pj5�/�*�� O!�T��G��I�?�cD�
�B:�O1�2g��C?���R��<�!tY�C׵»�F�*�!��#���bD��[1"�Mi����h���n�#��7Z�0J�M���J�4�/�*�j#B�*�<�2���l�,F��[�MF��v+L�lwk�sb����0���9"��輆P��?�B��~�|
a|�:�B�k�#��9"�dA���^B���������.�#)��B(]7�B������j#��u1!L;����	����P��ĄP	�6O!tY�d4��mbB�I(��)"L=y���a.����������Y3~�      x   N  x��S�n�0<S_���d'�ѕ��y ���^hjm�,I9u��+�V����Ý��٢���u��Fx�VnыD z��@�;��m@�1��JF��G�j��h�������l2��{m��=f�����Ob%[Ɵi�٠�-<�����D��Pu�/�G�ۋ���S�p��(M.f�u�j��2�dƄ��O��1��|�����<X����[r����I���ܤ�l�`�%k���i����l��+q�|6!�V��EM��So�+�����t�3x�G۰)�S�xt���K>!����@-=��"<"fU2]|{���͂�˹zD��g�B�\_"��/=���G������Ĵ�\��,	���K�C�~��u�N�>~ �k���y����_�sI�o�8}1�=�w��,Ei"�s%g�@=8k�=4�x�?@#,��0��g�LhR�G���@էL�$��^�={
Kj��v�;K����ɠ��,��h�:�_�@����g�=�Z��4��P���LrQ%�w���dEQUe��<��Jz��\p�8���׉���i}����t���I_�c�y�e �<��      y   �  x�-SK�![7�y%?Ż����p1�C!!�gK?M�t�V���4�b��%�2�e#�����S[���p��*2"�-�v�*#�ta��/S�Y�=+'�9�'ltjra���%l�0��8{���B~,1(3 1)� ����r�0�j��P]�u\�� �W�B��8>^���Nr�F�q���+F�P#�8�����+N���k Q��2P�������DE�G��z5D��q{��5�*�ܤJ���	*9:$����$�i7c�[r�LM.ɐőD���8�`G�8�Wg �v�i3@�w&�{�l�1�/���ވ��=����h�+�5�²�}�w9t	���!����1
K��z�C9n/����ct�����[�d?�s�$)����#��Q��o��0@��b>��~dKI��Z((Y�[���7y���\�<f���.J�����ݞ!�&��%�m#����e7�ˏ�^�z�S~"�/���      z   �  x�ŖK�� ��է� ���{;�f1Ȇ��1�`���S@kD+�4��w4���>����P6�,��Li�Z�%�w��ulVSϤ���xC�V92ᘓVx9�{��Z_��������Ӥ�2�Oܝ����F�`�̄fBJգ���
x��bqD�Ԇ_��F<�Y�q�g�	�*p>3c��`���1����ᦪ���$T��nr`�:�M��A���D�5�.p��&^��G���y��sIEBq��~99��-'ϯH�9������ɉ��h9y~͞�I��Ż��s���x�-'�/�UU_̏���AY<S[={GA��o'ᱧթO
�9U

�H?�xU�򷿅�Х	@��Y&=�P�ؚ--�bu�z	D�G%'|L����B|�I�ҿV{$���~�앤�c!	TE�l2γ�XԐ�`�%A6�.�9�oa��q2n3��n����a��lǜ:5q[�����q����{9?�N��oe�)�      {   J  x��W�n�6=+_�p\�V����.v��(���^h���P�JRv�S���/�̐�d�F�(ĶH�g޼y��y����"����z�}|��7��Z�*۾e�����l{bJ8�\�����?4˻|���ﴳ^���MV</���l��r�Qd��2/�i�\�?�6 '�e���Hk�I��*c~��Z�y�,��7>�`�!ش��7�5f,s�t�ɽF;�Y��|ȇ3���eR�T/t%f�1�a���2�Qh���ޡɧ�'.U��v�B�������iy��ӉZ8o%���c޿���Q��������\k
�{&t��^XǦ�1��*�<.WO�٣��=P�ډ++�d�����.mE{	�_�Κ|)������h��"&�S�U�=}��.�]G�~2J�cH�a�2N���iJ�A4�Rb�kr��hs�4AkA�]��M�.��B68�{@ɴl�ii�o�^\;�����Ğ+����Vg����!p��g�1�a#��V�
��=sV��� �0��Wкf��{H���i�z*�ي?z����v� ܱ�;'A@8E^��.����B�lx��`^�-=�;�,�!�����bp�����~Z��w]3� ��il�5pb��2[�r0� �1A�1��4�B�� _�T�dŵW'��!�	Ia��F&��.��[�����9��|�\��k+_ĕ*��*a�O+�3�b5#4*�x���V�%p�h���ι�g�~��ɖ�T}y�_I[���|�����������5F��S/�ehnX�#^
e�N�Up%�x�Q�V�B����p3�6DO�/BR�C�����&"�s,������0�E|^�%:("���9�-|^�Y@m��	\FF	��&�2_�yK�z˧S�Ը'1lb��{JF9lo���"�^V�#"�
.t���`]��ng�����1�7{�3Ar��B�Q���y{�h9~���w0�qP�;(�N���F=���u����}s	#���F��p0�ƴ��a���2U�� �r�"@�W�
M*�uXR
�3eà��*@t���pA� �[aH����S������A�t оIk=�|B�$.���	���@k��`�@�����iZr\��4F+p����1�៸���Ąupڀb�'�-��Qn���RnkC� /�3���!�j�I�:T�L�C<%IO�S��l_0ꠛ@0�!&�;� �%�	�\S�R��HU3�5(.��������X���5U5���$^=)��8�����	07�v�+��҅���g:�(]@j�;��َq%p�I:���Q:�o�W�DY\ZG،���:4���0�� )�� g����W?��(��AL����F ��r5#��Iܐ|�"q9d��n8G7w��]��@���G��ҕ)�L������'�9,~��"�7e��;od���z�� ���Xn���w�Zj��a���uM�a��-�=�xn��[P��J�w��e1g�+t�����ʤo�/�$�Za��6~J�|�-�rc���� ����zl����V�v�+�J˻�˻��.,6      |      x�3����� h �     