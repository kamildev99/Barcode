




CREATE function [dbo].[fun_barcodeShortener] 
(@BarcodeNEW varchar(1000)) returns varchar(1000)
as 
BEGIN
--declare @BarcodeNEW varchar(1000) = '12345>810009513>81122'
DECLARE @i int = 1 

DECLARE @tablePairs TABLE(
	id int identity(1,1),
	String nvarchar(2),
	type char(1) --A - alpha numeryczny, N - numeric
	)


WHILE( @i <= LEN(@BarcodeNEW))
	BEGIN

	IF SUBSTRING(@BarcodeNEW, @i , 1) = '>'
	BEGIN
		INSERT INTO  @tablePairs SELECT SUBSTRING(@BarcodeNEW, @i , 2), 'S'
		SET @i = @i + 1
	END
	ELSE
	BEGIN
		INSERT INTO  @tablePairs SELECT SUBSTRING(@BarcodeNEW, @i , 1), (case when SUBSTRING(@BarcodeNEW, @i , 1) like '[0-9]' then 'N' else 'A' END)
	END
		
		
		set @i = @i + 1
	END

--	SELECT *, 1 as tu FROM @tablePairs


	DECLARE @currentType char(1) = 'A'--zaczynamy od alfanumerycznego 
	DECLARE @barcodePrzetworzony as nvarchar(1000)

	DECLARE @pointerA int = 0 --wskaznik na alfanumeryczny
	DECLARE @pointerN int = 0 --wskaznik na numeryczny
	DECLARE @stringAlfa nvarchar(200) = '' --podciag alfanumeryczny 
	DECLARE @stringNumeric nvarchar(200) = '' --podciag numeryczny do zliczania by przypisywac do barcode i wstawian
	DECLARE @isNotSign5 bit = 0  --bit do psrawdzenia znaku >5

	IF (SELECT count(*) FROM @tablePairs WHERE id <=4 and type = 'N') = 4 
	BEGIN
	--startc
		set @currentType = 'N'
		set @pointerN = 1
	END
	else
	BEGIN
		set @currentType = 'A'
		set @pointerA = 1
	END

	SET  @barcodePrzetworzony = case when @currentType = 'N' then ';' else ':' END  + '>8'

	DECLARE @idB int = 1 , 
	@StringB nvarchar(2),
	@typeB char(1),
	@tablePairsRows int = (SELECT count(*) FROM @tablePairs)

	
	

	while @idB <= @tablePairsRows
	BEGIN

		--pobieramy z tabeli wartość oraz typ wartości w 1 petli
		SELECT @StringB = string, @typeB = type FROM @tablePairs WHERE id= @idB	

		--dodanie na poczatku kodu kreskowego wartosci bez zadnego sprawdzenia
		--na ten moment powoduje przeklamanie w mocmecnie gdy ruszamy 
		--SELECT @barcodePrzetworzony = @barcodePrzetworzony +  @StringB



		IF @currentType in('N') -- sprawdzenie czy w trybie N
		BEGIN
			IF(SELECT type FROM @tablePairs WHERE id = @idB) in ('N') --jezeli kolejne znaki sa n lub specjalne to sobie dodawaj
			BEGIN
				SELECT @stringNumeric = @stringNumeric + String FROM @tablePairs WHERE id = @idB

				if(@idB - @pointerN) > 3 and @isNotSign5 = 1
					BEGIN
						SELECT @stringNumeric = '>5' + @stringNumeric 
						set @isNotSign5 = 0
					END
			END
			ELSE 
			BEGIN
				IF(@idB - @pointerN) > 3 and @isNotSign5 = 1 
					BEGIN
						SELECT @stringNumeric = '>5' + @stringNumeric 
						SET @isNotSign5 = 0
					END


				SET @isNotSign5 = 1
				
				IF	(@idB - @pointerN) > 3 
				BEGIN
					
					IF((@idB  - @pointerN) % 2 = 1 and CHARINDEX('>8', @stringNumeric, 1) = 0) or (@idB  - @pointerN) % 2 = 0 and CHARINDEX('>8', @stringNumeric, 1) <> 0 --jezeli nie parzysta to robimy podciag parzysty i wstawiamy znak przejscia przed 1 numerycznym
					BEGIN
--							
							SELECT @barcodePrzetworzony = @barcodePrzetworzony + substring(@stringNumeric,1, len(@stringNumeric)-1) + '>6' + substring(@stringNumeric, len(@stringNumeric), 1)
							

							SELECT @pointerA = @idB - 1
					END
					else -- w przeciwnym razie wstawiamy znak przejscia po calym ciagu numerycznym
					BEGIN
							
							SELECT @barcodePrzetworzony = @barcodePrzetworzony + @stringNumeric  + '>6'
							SELECT @pointerA = @idB
					END
					
					
					
				END
				else	-- jezeli nie jest podciag numeryczny zlozony z co najmniej 4 znakow 
				BEGIN
				
					SELECT @barcodePrzetworzony = @barcodePrzetworzony + @stringNumeric
					SELECT @pointerA = @idb
				END
					SELECT @stringAlfa = @stringAlfa 
					SELECT @stringNumeric = '' --wyzerowanie podciagu 
					SELECT @currentType = 'A'
			END
		
			
		END



		IF @currentType in ('A', 'S')  -- sprawdzenie czy w trybie A
		BEGIN
			if(SELECT type FROM @tablePairs WHERE id = @idB) in ('A', 'S')
			BEGIN
				SELECT @stringAlfa = @stringAlfa + String FROM @tablePairs WHERE id = @idb
			END

			else 
			BEGIN
				
				SELECT @barcodePrzetworzony = @barcodePrzetworzony + @stringAlfa 
								
				SELECT @stringNumeric = @stringNumeric + String FROM @tablePairs WHERE id = @idB
				
				SELECT @pointerN = @idB
				SELECT @currentType = 'N'
				SELECT @stringAlfa = ''
				set @isNotSign5 = 1
			END
		END
		

		set @idB = @idB + 1
	END

	--ostateczne sprawdzenie
	IF(ISNULL(@stringNumeric, '') <> '' AND @currentType = 'N')
	BEGIN
		IF (LEN(replace(replace(replace(@stringNumeric, '>8', ''), '>6', ''), '>5', '')) % 2 = 1 and LEN(@stringNumeric) > 3)  --(LEN(replace(@stringNumeric, '>', '')) % 2 = 1 and LEN(@stringNumeric) > 3) 
		BEGIN
		 SELECT @barcodePrzetworzony = @barcodePrzetworzony + substring(@stringNumeric, 1, LEN(@stringNumeric)-3) + '>6' + SUBSTRING(@stringNumeric, LEN(@stringNumeric)-2, 3)	
		 
		END
		else
		BEGIN
		IF ( LEN(@stringNumeric) > 3 and LEN(replace(@stringNumeric, '>', '')) % 2 = 0 and @stringNumeric like '%>5%')
		BEGIN
			SELECT @barcodePrzetworzony = @barcodePrzetworzony + SUBSTRING(@stringNumeric, 3, 1) + substring(@stringNumeric,1 ,2) + substring(@stringNumeric,4 ,LEN(@stringNumeric) -3)
		END
		else
		BEGIN
			SELECT @barcodePrzetworzony = @barcodePrzetworzony + @stringNumeric
		END
		 
		
		END
	END

	if(ISNULL(@stringAlfa, '') <> '' AND @currentType = 'A')
	BEGIN
		

		SELECT @barcodePrzetworzony = @barcodePrzetworzony + @stringAlfa 
		
	END
	
	IF(SUBSTRING(@barcodePrzetworzony, LEN(@barcodePrzetworzony)-1, 1) <> '>' and (SELECT TOP 1 type FROM @tablePairs ORDER BY ID DESC) = 'S')
	BEGIN
		SELECT @barcodePrzetworzony = @barcodePrzetworzony + '>8'
		
	END
	

	RETURN @barcodePrzetworzony

	END 
GO


