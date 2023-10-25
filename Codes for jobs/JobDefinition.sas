* El archivo JSON que espera este trabajo contiene el mensaje JSON modificado;
* que SAS Visual Analytics envió al objeto de contenido basado en datos;
* Contiene datos transformados y metadatos de columna adicionales.;
*==================================================================;
* Inicio del código;
*==================================================================;
* Esto permite nombres de columna no convencionales (por ejemplo, espacios, etc.);
options VALIDVARNAME=any;

* Recuperar datos JSON del archivo cargado;
filename vaJSON filesrvc "&_WEBIN_FILEURI" ;

* Use el motor JSON para proporcionar acceso secuencial de solo lectura a los datos JSON;
libname jsonLib json fileref=vaJSON;

* Crear una tabla para asistir en la creación de un archivo de mapa JSON;
* Reemplace los espacios en blanco en los nombres de las columnas con guiones bajos (_);
* La tabla de salida contiene el nombre de la columna, la etiqueta, el tipo, el formato, el ancho del formato y la precisión del formato;
%macro prepColMetadata;
	%if %sysfunc(exist(jsonLib.columns_format)) %then
		%do;

			proc sql noprint;
				create table col_metadata as (
					select 
						c.ordinal_columns, translate(trim(c.label),'_',' ') as column, 
						c.label, 
						c.type4job as type,
						f.name4job as fmt_name,
						f.width4job as fmt_width,
						f.precision4job as fmt_precision
					from jsonLib.columns c left join jsonLib.columns_format f
						on c.ordinal_columns = f.ordinal_columns
						);
			quit;

		%end;
	%else
		%do;
			* el formato de las columnas de la tabla no existe;
			* todas las columnas son cadenas (sin objeto de formato en la estructura JSON);
			proc sql noprint;
				create table col_metadata as (
					select 
						c.ordinal_columns, translate(trim(c.label),'_',' ') as column, 
						c.label, 
						c.type4job as type,
						"" as fmt_name,
						. as fmt_width,
						. as fmt_precision
					from jsonLib.columns c 
						);
			quit;

		%end;
%mend;

%prepColMetadata;
filename jmap temp lrecl=32767;

* Cree un archivo de mapa JSON que se usará para leer VA JSON con etiquetas, formatos, tipos, etc. adecuados.;
data _null_;
	file jmap;
	set col_metadata end=eof;

	if _n_=1 then
		do;
			put '{"DATASETS":[{"DSNAME": "data_formatted","TABLEPATH": "/root/data","VARIABLES": [';
		end;
	else
		do;
			put ',';
		end;

	if fmt_name ne "" then
		line=cats('{"PATH":"/root/data/element',ordinal_columns,
		'","NAME":"',column,
		'","LABEL":"',label,
		'","TYPE":"',type,
		'","FORMAT":["',fmt_name,'",',fmt_width,',',fmt_precision,']}');
	else
		line=cats('{"PATH":"/root/data/element',ordinal_columns,
		'","NAME":"',column,
		'","LABEL":"',label,
		'","TYPE":"',type,'"}');
	put line;

	if eof then
		do;
			put ']}]}';
		end;
run;

* Reasigne el motor JSON libname para proporcionar acceso secuencial de solo lectura a datos JSON, ahora con mapa;
libname jsonLib json fileref=vaJSON map=jmap;

* Copia de la tabla JSON;
data _Aux2_;
	set jsonLib.data_formatted;
run;

*==================================================================;
* Creación de Template de Salida;
*==================================================================;
proc template;
	define style Styles.Custom;
		parent = Styles.Printer;
		replace fonts /
			'TitleFont' = ("Arial",13pt) /* Titles from TITLE statements */

		'TitleFont2' = ("Arial",10pt )/* Proc titles ("The XX Procedure")*/

		'StrongFont' = ("Arial",10pt)

		'EmphasisFont' = ("Arial",10pt)
		'headingEmphasisFont' = ("Arial",10pt)
		'headingFont' = ("Arial",10pt) /* Table column and row headings */

		'docFont' = ("Arial",10pt) /* Data in table cells */
		'footFont' = ("Arial",13pt) /* Footnotes from FOOTNOTE statements */

		'FixedEmphasisFont' = ("Courier",10pt,Italic)
		'FixedStrongFont' = ("Courier",10pt)
		'FixedHeadingFont' = ("Courier",10pt)
		'BatchFixedFont' = ("Courier",6.7pt)
		'FixedFont' = ("Courier",10pt);
		replace color_list /
			'link' = blue /* links */

		'bgH' =  white /* row and column header background */
		'bgT' = white /* table background */
		'bgD' = white /* data cell background */
		'fg' = black /* text color */
		'bg' = white; /* page background color */
		style Table from Table / 
		frame = hsides 
		rules = groups 
		cellpadding = 0pt 
		cellspacing = 0pt 
		/*  borderwidth = 0.08pt */

		/*outputwidth = 100% */
		Background=_undef_ 
		protectspecialchars = off;
		style PrePage from PrePage/ 
			outputwidth = 100% 
			asis = on 
			just = left 
			protectspecialchars = off;
		replace Header from Header / 
			asis = on 
			just = center 
			protectspecialchars = off;
		style UserText from UserText/ 
			font = Fonts('footFont') 
			outputwidth = 100% 
			asis = on 
			just = left 
			protectspecialchars = off;
		replace SystemFooter from TitlesAndFooters / 
			font = Fonts('footFont') 
			asis=on 
			outputwidth = 100%;
		style parskip / fontsize = 0pt;
		style graphaxislines from graphaxislines / 
			linestyle=1 linethickness=2px;
		style graph from graph / 
			bordercolor=black borderwidth=2px;
	end;
quit;

*==================================================================;
* Inicio de procesamiento del reporte;
*==================================================================;
/*Actualizar Carpeta Serie para que no reconozca %PIB como Macro Variable*/
proc sql;
	update _Aux2_ set Desc_CarpetaSerie=tranwrd(Desc_CarpetaSerie,"%","% ") ;
quit;
/*Calculo de Macro variables*/
proc sql noprint;
	select distinct Desc_GrupoSerie into:_GrupoSerie_ trimmed
		from _Aux2_;
	select distinct Id_CarpetaSerie into:_IdCarpeta_ trimmed
		from _Aux2_;
	select distinct Id_SubCarpetaSerie into:_IdSubCarpeta_ trimmed
		from _Aux2_;
	select distinct Desc_CarpetaSerie into:_DescCarpeta_ trimmed
		from _Aux2_;
	select distinct Id_Moneda into:_NombreMoneda_ trimmed
		from _Aux2_;
	select distinct propcase(Desc_UnidadMedidaSerie) into:_Desc_UnidadMedidaSerie_ trimmed
		from _Aux2_;
	select distinct Desc_FuenteSerie into:_Desc_Fuente_ trimmed
		from _Aux2_;
quit;

ods escapechar="^";
filename f_xlxp filesrvc parenturi="&SYS_JES_JOB_URI"
	name='File.xlsx' 
	contenttype='application/vnd.ms-excel' 
	contentdisp='attachment; filename="File.xlsx"';
ods 
	excel file=f_xlxp style=custom
	options (embedded_titles='yes' 
	suppress_bylines='yes'
	print_header='&C&A');

*==================================================================;
* Reporte de Metadatos;
*==================================================================;
%macro ReporteMetadatos;
	%if &_IdSubCarpeta_. =20400 Or &_IdCarpeta_. =1121  %then
		%do;
			/*Crear una tabla auxiliar con los valores requeridos para el reporte*/
			proc sql;
				create table _Aux21_ as
					select distinct Serie,
						Desc_Periodicidad,
						Desc_UnidadMedidaSerie,
						Desc_FuenteSerie,
						Fecha_DesdeDatos,
						Fecha_HastaDatos,
						tranwrd(Desc_NotasPublicar,"(ausente)","") as Desc_NotasPublicar length=32767
					from _Aux2_;
			quit;

			data _null_;
				Fecha=today();
				Hora=time();
				call symput ('_Fecha_',  put(Fecha,DDMMYYS10.));
				call symput ('_Hora_', put(Hora, TIMEAMPM.));
			run;

			ods excel options(sheet_name="Metadatos");

			proc report data=_Aux21_ NOWD
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col Serie
					Desc_Periodicidad
					Desc_UnidadMedidaSerie
					Desc_FuenteSerie
					Fecha_DesdeDatos
					Fecha_HastaDatos
					Desc_NotasPublicar;
				define Serie /'Serie' group left order=internal style={ cellwidth=3.030 in};
				define Desc_Periodicidad /'Periodicidad' display left;
				define Desc_UnidadMedidaSerie /'Unidad de medida' display left;
				define Desc_FuenteSerie /'Fuente' display left;
				define Fecha_DesdeDatos /'Disponible desde' display left;
				define Fecha_HastaDatos /'Disponible hasta' display left;
				define Desc_NotasPublicar /'Notas' display left;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Metadatos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line " ";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
				endcomp;
			run;

		%end;
	%if &_IdCarpeta_. =1085 or &_IdSubCarpeta_. =21400 %then
		%do;
			/*Crear una tabla auxiliar con los valores requeridos para el reporte*/
			proc sql;
				create table _Aux21_ as
					select distinct Serie,
						Desc_Periodicidad,
						Desc_Base,
						Desc_UnidadMedidaSerie,
						Desc_FuenteSerie,
						Fecha_DesdeDatos,
						Fecha_HastaDatos,
						tranwrd(Desc_NotasPublicar,"(ausente)","") as Desc_NotasPublicar length=32767
					from _Aux2_;
			quit;

			data _null_;
				Fecha=today();
				Hora=time();
				call symput ('_Fecha_',  put(Fecha,DDMMYYS10.));
				call symput ('_Hora_', put(Hora, TIMEAMPM.));
			run;

			ods excel options(sheet_name="Metadatos");

			proc report data=_Aux21_ NOWD
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col Serie
					Desc_Periodicidad
					Desc_UnidadMedidaSerie
					Desc_Base
					Desc_FuenteSerie
					Fecha_DesdeDatos
					Fecha_HastaDatos

					Desc_NotasPublicar;
				define Serie /'Serie' group left order=internal style={ cellwidth=3.030 in};
				define Desc_Periodicidad /'Periodicidad' display left;
				define Desc_UnidadMedidaSerie /'Unidad de medida' display left;
				define Desc_Base /'Base' display left;
				define Desc_FuenteSerie /'Fuente' display left;
				define Fecha_DesdeDatos /'Disponible desde' display left;
				define Fecha_HastaDatos /'Disponible hasta' display left;
				define Desc_NotasPublicar /'Notas' display left;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Metadatos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line " ";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
				endcomp;
			run;

		%end;
	%if &_IdCarpeta_.=1090 or  &_IdCarpeta_.=1100 or &_IdCarpeta_.=1120 or &_IdCarpeta_.=1122 or &_IdCarpeta_.=1350 %then
		%do;
			/*Crear una tabla auxiliar con los valores requeridos para el reporte*/
			proc sql;
				create table _Aux21_ as
					select distinct Serie,
						Desc_Periodicidad,
						Desc_UnidadMedidaSerie,
						Id_Moneda,
						Desc_fuenteSerie,
						Fecha_DesdeDatos,
						Fecha_HastaDatos,
						tranwrd(Desc_NotasPublicar,"(ausente)","") as Desc_NotasPublicar length=32767
					from _Aux2_;
			quit;

			data _null_;
				Fecha=today();
				Hora=time();
				call symput ('_Fecha_',  put(Fecha,DDMMYYS10.));
				call symput ('_Hora_', put(Hora, TIMEAMPM.));
			run;

			ods excel options(sheet_name="Metadatos");

			proc report data=_Aux21_ NOWD
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col Serie
					Desc_Periodicidad
					Desc_UnidadMedidaSerie
					Id_Moneda
					Desc_FuenteSerie
					Fecha_DesdeDatos
					Fecha_HastaDatos
					Desc_NotasPublicar;
				define Serie /'Serie' group left order=internal style={ cellwidth=3.025 in};
				define Desc_Periodicidad /'Periodicidad' display left;
				define Desc_UnidadMedidaSerie /'Unidad de medida' display left;
				define Id_Moneda /'Moneda' display left;
				define Desc_FuenteSerie /'Fuente' display left;
				define Fecha_DesdeDatos /'Disponible desde' display left;
				define Fecha_HastaDatos /'Disponible hasta' display left;
				define Desc_NotasPublicar /'Notas' display left;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Metadatos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line " ";
					line "^S={just=l }Cifras de datos en &_Desc_UnidadMedidaSerie_. de &_NombreMoneda_.";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
				endcomp;
			run;

		%end;

	%if &_IdCarpeta_. = 1105 /*or &_IdCarpeta_. = 1121*/ or &_IdCarpeta_. = 1130 %then
		%do;
			/*Crear una tabla auxiliar con los valores requeridos para el reporte*/
			proc sql;
				create table _Aux21_ as
					select distinct Serie,
						Desc_Periodicidad,
						Desc_UnidadMedidaSerie,
						Id_Moneda,
						Desc_fuenteSerie,
						Fecha_DesdeDatos,
						Fecha_HastaDatos,
						tranwrd(Desc_NotasPublicar,"(ausente)","") as Desc_NotasPublicar length=32767
					from _Aux2_;
			quit;

			data _null_;
				Fecha=today();
				Hora=time();
				call symput ('_Fecha_',  put(Fecha,DDMMYYS10.));
				call symput ('_Hora_', put(Hora, TIMEAMPM.));
			run;

			ods excel options(sheet_name="Metadatos");

			proc report data=_Aux21_ NOWD
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col Serie
					Desc_Periodicidad
					Desc_UnidadMedidaSerie
					Id_Moneda
					Desc_fuenteSerie
					Fecha_DesdeDatos
					Fecha_HastaDatos
					Desc_NotasPublicar;
				define Serie /'Serie' group left order=internal style={ cellwidth=3.025 in};
				define Desc_Periodicidad /'Periodicidad' display left;
				define Desc_UnidadMedidaSerie /'Unidad de medida' display left;
				define Id_Moneda /'Moneda' display left;
				define Desc_FuenteSerie /'Fuente' display left;
				define Fecha_DesdeDatos /'Disponible desde' display left;
				define Fecha_HastaDatos /'Disponible hasta' display left;
				define Desc_NotasPublicar /'Notas' display left;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Metadatos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line " ";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
				endcomp;
			run;

		%end;
%mend;

%ReporteMetadatos;

*==================================================================;
* Reporte de Datos;
*==================================================================;
/*Crear una tabla auxiliar con los valores requeridos para el reporte*/
proc sql;
	create table  _Aux3_ as
		select *
			from _Aux2_
	;
quit;

%macro ReporteDatos;
	%if &_IdCarpeta_. =1080 or &_IdCarpeta_. =1085 or &_IdCarpeta_. =1105 or &_IdCarpeta_. =1121 %then
		%do;
			ods excel options(sheet_name="Series de datos");

			proc report data=_Aux3_  NOWD 
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col   Fecha Serie,  Valor;
				define Fecha /' ' GROUP  center FORMAT=DDMMYYS10. order=internal;
				define Serie /'Serie' ACROSS left;
				define Valor /' ' ANALYSIS sum format=COMMAx32.2 nozero center;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Datos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line "";
					line "^S={just=l }Los valores ausentes se indican con un punto (.)";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
					
				endcomp;
			run;

		%end;

		%if &_IdCarpeta_. =1120 or &_IdCarpeta_. =1122 %then
		%do;
			ods excel options(sheet_name="Series de datos");

			proc report data=_Aux3_  NOWD 
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col   Fecha Serie,  Valor;
				define Fecha /' ' GROUP  center FORMAT=DDMMYYS10. order=internal;
				define Serie /'Serie' ACROSS left;
				define Valor /' ' ANALYSIS sum format=COMMAx32.2 nozero center;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Datos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line "";
					line "^S={just=l }Cifras de datos en &_Desc_UnidadMedidaSerie_. de &_NombreMoneda_.";
					line "^S={just=l }Los valores ausentes se indican con un punto (.)";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
					
				endcomp;
			run;

		%end;

	%if &_IdCarpeta_. =1130 %then
		%do;
			ods excel options(sheet_name="Series de datos");

			proc report data=_Aux3_  NOWD 
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col   Fecha Serie,  Valor;
				define Fecha /' ' GROUP  center FORMAT=DDMMYYS10. order=internal;
				define Serie /'Serie' ACROSS left;
				define Valor /' ' ANALYSIS sum format=COMMAx32.2 nozero center;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Datos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line "";
					line "^S={just=l }Los valores ausentes se indican con un punto (.)";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
					
				endcomp;
			run;

		%end;

	%if  &_IdCarpeta_. =1090 or  &_IdCarpeta_. =1100 or  &_IdCarpeta_. =1350 %then
		%do;
			ods excel options(sheet_name="Series de datos");

			proc report data=_Aux3_ split="~"  NOWD 
				style(report)=[fontfamily='Arial' fontsize=9  rules=group bordercolor=white outputwidth = 100% ]
				style(header)=[just=c asis=on borderbottomcolor=black borderbottomwidth=0.5  font_weight=bold
				background=#004677 foreground=white]
				style(lines)=[ vjust=m color=white   ]
				style(column)=[ vjust=m  ];
				Col Serie  Fecha,  Valor;
				define Serie /'Serie' GROUP left  style={tagattr='wrap:no' cellwidth=3.025 in};
				define Fecha /' ' ACROSS  center FORMAT=DDMMYYS10. order=internal style={ tagattr='wrap:no type:DateTime'};
				define Valor /' ' ANALYSIS sum format=COMMAx32.2  nozero center;

				compute before _page_ / style=[borderbottomcolor=black  font_weight=bold borderbottomwidth=0.5 fontsize=10pt
					background=white color=black];
					line "Datos del Grupo Serie: &_GrupoSerie_. (&_DescCarpeta_.)";
					line " ";
				endcomp;

				compute after _page_ / style=[just=left bordertopcolor=black bordertopwidth=0.5 fontsize=9pt
					background=white color=black ];
					line "";
					line "^S={just=l }Cifras de datos en &_Desc_UnidadMedidaSerie_. de &_NombreMoneda_.";
					line "^S={just=l }Los valores ausentes se indican con un punto (.)";
					/*line "^S={just=l }Fuente: &_Desc_Fuente_..";*/
					line "^S={just=l }Descargado del sistema del Banco de la República: &_Fecha_. &_Hora_.";
					
				endcomp;
			run;

		%end;

%mend;

%reporteDatos;
ods excel close;
%let EXCEL_LINK=%bquote(
	<a href=""&_FILESRVC_F_XLXP_URI/content"" target=""_SASDLResults"" id=""BotonDescargar"" >
	<img src="https://gue.banrep.gov.co/htmlcommons/SeriesHistoricas/img/sh-icon-descargar.png">            
	</a>
	);
filename f_htm  filesrvc parenturi="&SYS_JES_JOB_URI" name ='_webout.htm';
ods html5 style=&_ODSSTYLE file=f_htm 

	text= "<span>^{style systemtitle &EXCEL_LINK}</span>";
ods html5 close;
%put Esta es la URL del archivo creado por el Job: &_FILESRVC_F_XLXP_URI/content;

*==================================================================;
* Finalización de procesamiento del reporte;
*==================================================================;
*==================================================================;
* Fin del código;
*==================================================================;