

/*1.1 Creation of a macro to import the Excel datas*/
%macro Importation(datafile=, name=);
proc import 
datafile="&datafile."
    out=work.&name. 
    dbms=excel 
    replace; 
    sheet="Sheet1"; 
    getnames=yes;   
run;
%mend Importation;

/*Loading of our Excel sheets using the macro*/
%let path = C:\Users\roman\Downloads\VaR_Memoire_S2\Data;

%Importation(datafile=&path.\cac40.xlsx, name=CAC40); /* We load CAC40 sheet */
%Importation(datafile=&path.\DataGDAXI.xlsx, name=DAX); /* We load DAX sheet */
%Importation(datafile=&path.\SSMI.xlsx, name=SMI); /* We load SMI sheet */
%Importation(datafile=&path.\FTSE.xlsx, name=FTSE100); /* We load FTSE100 sheet */
%Importation(datafile=&path.\IBEX.xlsx, name=IBEX35); /* We load IBEX35 sheet */
%Importation(datafile=&path.\MDAXI.xlsx, name=MDAXI); /* We load IBEX35 sheet */

%macro Sorting(dataset=, variables=);
	proc sort data=&dataset.;
		by &variables.;
	run;
%mend Sorting;

%Sorting(dataset=work.CAC40, variables=date);
%Sorting(dataset=work.Dax, variables=date);
%Sorting(dataset=work.SMI, variables=date);
%Sorting(dataset=work.FTSE100, variables=date);
%Sorting(dataset=work.IBEX35, variables=date);
%Sorting(dataset=work.MDAXI, variables=date);

%macro RenameClose(dataset=,name=, label=);
	data work.&dataset.;
		set work.&dataset.;
		rename Close = &name.;
        	label &name. = "&label.";
	run;
%mend RenameClose;
%RenameClose(dataset=CAC40, name=CAC40_Prices,label=CAC40_Prices);
%RenameClose(dataset=Dax, name=DAX_Prices, label=DAX_Prices);
%RenameClose(dataset=SMI, name=SMI_Prices, label=SMI_Prices);
%RenameClose(dataset=FTSE100, name=FTSE100_Prices, label=FTSE100_Prices);
%RenameClose(dataset=IBEX35, name=IBEX35_Prices, label=IBEX35_Prices);
%RenameClose(dataset=MDAXI, name=MDAXI_Prices, label=MDAXI_Prices);


data work.Newdataset;
	merge 	work.CAC40 (keep= date CAC40_Prices in=inCAC40) 
			work.Dax (keep= date DAX_Prices in=inDAX)
			work.SMI (keep= date SMI_Prices in=inSMI)
			work.FTSE100 (keep= date FTSE100_Prices in=inFTSE100)
			work.IBEX35(keep= date IBEX35_Prices in=inIBEX35)
			work.MDAXI (keep= date MDAXI_Prices in=inMDAXI);


	by date;

	/*creation of indicators to see what values are missing*/
	if inCAC40=0 then CAC40_Prices =.;
	if inDAX=0 then DAX_Prices =.;		
	if inSMI=0 then SMI_Prices =.;		
	if inFTSE100=0 then FTSE100_Prices =.;
	if inIBEX35=0 then IBEX35_Prices =.;
	if inMDAXI=0 then MDAXI_Prices =.;


run;


proc means data=newdataset  nmiss; run; 
proc contents data=newdataset; run;
proc means data=newdataset; run; 

/*les valeurs manquantes*/

%macro Dropnan(inputdata=, outputdata=, vars=);
data &outputdata.;
    set &inputdata.;
    array _verifnan {*} &vars.; /*crée un tableau nommé verifnan contenant toutes les variables*/
    nbr_nan = 0; /*initialisation d'un compteur*/
    do i = 1 to dim(_verifnan); /*ce boucle permet de garder les lignes où il y'a aucune nan et les autres sont ingoré donc ne les incluent pas dans verifnan*/
        if missing(_verifnan{i}) then nbr_nan+1;
    end;
    if nbr_nan = 0; /* garde uniquement les lignes sans NA */
    drop i nbr_nan;
run;
%mend Dropnan;
%Dropnan(
    inputdata=newdataset,
    outputdata=CleanedDataset,
     vars=CAC40_Prices DAX_Prices SMI_Prices FTSE100_Prices IBEX35_Prices MDAXI_Prices); /*217 supprimé*/




proc means data=CleanedDataset  nmiss; run; /*0 nan*/
proc contents data=cleanedDataset; run;

/*calcules des rendements (%scan est une fonction qui extrait le nième mot (ou élément) d’une chaîne de texte séparée par des espaces.*/
%macro calc_logreturns(inputdata=, outputdata=, vars=);

data &outputdata.;
    set &inputdata.;
    
    %let keepvars=Date; /*initialisation d'une chaine vide qui contiendra les noms des nouvelles variables de rnd */

    %let i = 1;
    %do %while (%scan(&vars., &i.) ne ); /*une boucle qui récupère les i variable dans vars tant qu'il y en a*/
        %let var = %scan(&vars., &i.); /*ces variables sont stoké dans var*/
        
        lag_&var. = lag(&var.);
        
        if &var. > 0 and lag_&var. > 0 then
            rnt_&var. = log(&var. / lag_&var.);
        else
            rnt_&var. = .;
        
        %let keepvars = &keepvars rnt_&var.;
        %let i = %eval(&i. + 1);
    %end;

    keep &keepvars.;

run;

%mend;

%calc_logreturns(
    inputdata=cleanedDataset,
    outputdata=logreturn,
    vars=CAC40_Prices DAX_Prices SMI_Prices FTSE100_Prices IBEX35_Prices MDAXI_Prices
);

proc means data=logreturn nmiss; run;
data logreturn_clean;
    set logreturn;
    if cmiss(of _numeric_) = 0; /* garde uniquement les lignes complètes */
run;

proc means data=logreturn_clean nmiss; run;



data portefeuille_final;
    set logreturn_clean;

    /* Pondération égale pour chaque indice (1/6) */
    port_return = 
        (1/6) * rnt_CAC40_Prices +
        (1/6) * rnt_DAX_Prices +
        (1/6) * rnt_SMI_Prices +
        (1/6) * rnt_FTSE100_Prices +
        (1/6) * rnt_IBEX35_Prices +
        (1/6) * rnt_MDAXI_Prices;

    label port_return = "Rendement log du portefeuille (équipondéré)";
run;

%macro plot_series(data=, datevar=, vars=);

    %let i = 1;
    %do %while (%scan(&vars., &i.) ne );
        %let var = %scan(&vars., &i.);

        title "Évolution du rendement log de &var.";

        proc sgplot data=&data.;
            series x=&datevar. y=&var. / lineattrs=(thickness=1.5 color=blue);
            yaxis label="Rendement log";
            xaxis label="Date";
        run;

        %let i = %eval(&i. + 1);
    %end;

%mend;

%plot_series(
    data=portefeuille_final,
    datevar=Date,
    vars=rnt_CAC40_Prices rnt_DAX_Prices rnt_SMI_Prices rnt_FTSE100_Prices rnt_IBEX35_Prices rnt_MDAXI_Prices port_return
);


proc univariate data=portefeuille_final;
    var port_return;
    histogram port_return / normal;
    inset mean std skewness kurtosis min max / position=ne cfill=blank;
run; 

/*test ACF PACF*/
proc timeseries data=portefeuille_final plots=(series acf pacf);
    id date interval=day;   /* ou month, week selon ton cas */
    var port_return;
run; /*pas d'autocorélation sur les rdt*/

data portefeuille_final;
    set portefeuille_final;
    port_sq = port_return**2;
run;

/*verification de l'autocorrélation pour les rnd**2 */
proc arima data=portefeuille_final;
    identify var=port_sq nlag=20;
run;

/*test ARCH*/

proc autoreg data=portefeuille_final;
    model port_return = / nlag=1 archtest;
run; /*on constate la presence d'effet ARCH*/


/*GARCH*/
proc autoreg data=portefeuille_final;
    model port_return = / garch=(p=1, q=1) dist=t;
    output out=garch_out cev=variance_garch_t residual=resid_t;
run; /*il y'a effet garch aussi*/

/* Calculons l'écart-type conditionnel à partir de la variance */
data garch_plot;
    set garch_out;
    sigma_garch = sqrt(variance_garch_t); /* s? = v(Var?) */
run;

/* Tracer la série temporelle de s? */
proc sgplot data=garch_plot;
    series x=date y=sigma_garch / lineattrs=(color=blue thickness=2);
    xaxis label="Date" grid;
    yaxis label="Volatilité conditionnelle (s?)" grid;
    title "Volatilité conditionnelle estimée par le modèle GARCH(1,1)";
run;

/* Définir ? et les quantiles Student-t (11.76) */
%let nu = 11.7647;         /* Degré de liberté estimé par GARCH v=1/tdf1 */
%let z_95_t = -1.7965;     
%let z_99_t = -2.5697;     

/* Calculer la VaR conditionnelle */
data var_calc;
    set garch_plot;

    /* Calcul écart-type conditionnel déjà effectué : sigma_garch */
    nu = &nu;
    z_95_t = &z_95_t;
    z_99_t = &z_99_t;

    VaR_95_t = z_95_t * sigma_garch;
    VaR_99_t = z_99_t * sigma_garch;
run;

/*comparaison entre var_95%,var_99% et rdt_réel*/
proc sgplot data=var_calc;
    /* Série des rdt réels */
    series x=date y=port_return / 
        lineattrs=(color=black thickness=1) 
        legendlabel="Rendement réel";

    /* VaR 95% */
    series x=date y=VaR_95_t / 
        lineattrs=(color=red pattern=shortdash thickness=2) 
        legendlabel="VaR 95% (Student-t)";

    /* VaR 99% */
    series x=date y=VaR_99_t / 
        lineattrs=(color=blue pattern=dot thickness=2) 
        legendlabel="VaR 99% (Student-t)";

    xaxis label="Date";
    yaxis label="Rendements et VaR (en %)";
    title "Comparaison rendements réalisés et VaR conditionnelle (GARCH Student-t)";
run;



/* test de kupiec */
data backtest;
    set var_calc;
    exception_95 = (port_return < VaR_95_t);
    exception_99 = (port_return < VaR_99_t);

    label_95 = "VaR 95%"; alpha_95 = 0.05; e95 = exception_95;
    label_99 = "VaR 99%"; alpha_99 = 0.01; e99 = exception_99;
run;

proc summary data=backtest nway;
    output out=kupiec_95(drop=_type_ _freq_)
        sum(e95)=nb_exceptions n(e95)=nb_total;
    output out=kupiec_99(drop=_type_ _freq_)
        sum(e99)=nb_exceptions n(e99)=nb_total;
run;

data kupiec_95; set kupiec_95; alpha=0.05; label="VaR 95%"; run;
data kupiec_99; set kupiec_99; alpha=0.01; label="VaR 99%"; run;

data kupiec_all;
    set kupiec_95 kupiec_99;
    pi = nb_exceptions / nb_total;
    LL0 = nb_exceptions*log(alpha) + (nb_total - nb_exceptions)*log(1 - alpha);
    LL1 = nb_exceptions*log(pi) + (nb_total - nb_exceptions)*log(1 - pi);
    LR_POF = -2 * (LL0 - LL1);
    p_value = 1 - probchi(LR_POF, 1);
run;

/* 3. Affichage final dans un tableau résumé */
proc print data=kupiec_all label noobs;
    var label nb_exceptions nb_total pi LR_POF p_value;
    label 
        label = "Niveau de VaR"
        nb_exceptions = "Nb Exceptions"
        nb_total = "Nb Total"
        pi = "Taux observé"
        LR_POF = "Statistique de Kupiec"
        p_value = "P-value (H0 : VaR correcte)";
    title " Test de Kupiec – VaR conditionnelle à 95 % et 99 % (GARCH Student-t)";
run;

/*test de Christoffersen à 95 % et 99 %, */


proc iml;
  
    use backtest;
    read all var {exception_95 exception_99} into X; /*on charge les exceptions dans la matrice X*/
    close backtest;

    niveaux = {"VaR 95%", "VaR 99%"};
    result = j(2, 9, .); 

    do k = 1 to 2; /*un boucle sur les deux niveaux de var*/
        e = X[,k];
        n = nrow(e);

        /* Initialiser les compteurs */
        t00 = 0; t01 = 0; t10 = 0; t11 = 0;

        /*  Compter les transitions en construisant une matrice  */
        do i = 2 to n;
            if e[i-1]=0 & e[i]=0 then t00 = t00 + 1;
            else if e[i-1]=0 & e[i]=1 then t01 = t01 + 1;
            else if e[i-1]=1 & e[i]=0 then t10 = t10 + 1;
            else if e[i-1]=1 & e[i]=1 then t11 = t11 + 1;
        end;

        /*  proba conditionnelles */
        pi0 = t01 / (t00 + t01);
        pi1 = t11 / (t10 + t11);
        pi  = (t01 + t11) / (t00 + t01 + t10 + t11);

        /*  éviter log(0) */
        eps = 1e-10;
        pi0 = max(eps, min(pi0, 1 - eps));
        pi1 = max(eps, min(pi1, 1 - eps));
        pi  = max(eps, min(pi,  1 - eps));

        /*  log vrss */
        LL0 = (t00 + t10)*log(1 - pi) + (t01 + t11)*log(pi);
        LL1 = t00*log(1 - pi0) + t01*log(pi0) + t10*log(1 - pi1) + t11*log(pi1);

        /*  test et p-value */
        LR = -2 * (LL0 - LL1);
        p = 1 - cdf("chisq", LR, 1);

        /*  résultats */
        result[k,] = t00 || t01 || t10 || t11 || pi0 || pi1 || LR || p || k;
    end;

    /* Affichage final */
    print result[colname={
        "t00" "t01" "t10" "t11" "pi0" "pi1"
        "Stat_Christoffersen" "P_value" "Indice"
    } rowname=niveaux label="Test de Christoffersen – Indépendance des exceptions"];
quit;


/* EWMA PART */

* The tests to justify the use of ewma model have already been done within the GARCH part; 
* traduction : tests à appliquer pour utilisation ewma ==> ils ont déjà été fait pour GARCH !!
- RU (ADF) 
- autcorr des Rt (Ljung Box)
- autocorr des Rt^2 (test arch/ Ljung Box)  */

* We observe condtional volatility in the serie which justify th euse of ewma; 
*Présence de volatilite conditionnelle --> pertinence modèle EWMA ;
proc timeseries data=portefeuille_final plots=(series acf pacf);
    id date interval=day;   
    var port_sq;
run; 

/* Exponential Weighted Moving Average Computation */
proc iml;
/* Input */
use work.portefeuille_final;
read all var {port_sq} into Rt2; 
read all var {port_return} into Rt; 
close portefeuille_final;

lambda=0.94; /* we define the smoothing parameter (cf Risk Metrics) */
T =nrow(Rt2);
ewma_var=j(T,1,0);
sigma_ewma=j(T,1,0);

/* EWMA recursive formula used in Risk Metrics */
ewma_var[1] = Rt2[1]; 
Do i=2 to T;
	ewma_var[i] = lambda * ewma_var[i-1] + (1 - lambda) * Rt2[i];  
	sigma_ewma[i] = sqrt(ewma_var[i]);
end;

/* Output */
output = ewma_var||sigma_ewma;
create ewma_out from output[colname={"ewma_var" "sigma_ewma"}];
append from output;
close ewma_out;

print (Mean(sigma_ewma))[label="EWMA Volatility"];
quit;

/* ptf dataset with ewma info*/
data ewma_out;
	merge ewma_out (keep= ewma_var sigma_ewma in=inewma_out)
		portefeuille_final (keep= date port_return port_sq in=inportefeuille_final);
run;


/* Plot time series for ewma_var */
proc sgplot data=ewma_out;
    series x=date y=ewma_var/ lineattrs=(color=green thickness=2);
    xaxis label="Date" grid;
    yaxis label=" EWMA variance " grid;
    title "Estimated EWMA variance ";
run;

/* Plot time series for sigma_ewma */
proc sgplot data=ewma_out;
    series x=date y=sigma_ewma/ lineattrs=(color=green thickness=2);
    xaxis label="Date" grid;
    yaxis label=" EWMA volatility " grid;
    title "Estimated EWMA volatility ";
run;


/* PORTFOLIO WITH MERGED DATASETS, INCLUDES Rt + BOTH GARCH AND EWMA INFO */
data ewma_garch_rt;
	merge portefeuille_final (keep= date port_return port_sq in=inportefeuille_final)
			garch_plot (keep= resid_t variance_garch_t sigma_garch in=ingarch_out)
			ewma_out (keep= ewma_var sigma_ewma in=inewma_var);
run;

/* Define normal quantiles */
%let z_95 = -1.6449;
%let z_99 = -2.3263;

data var_calc_ewma;
    set ewma_out; 
    z_95 = &z_95;
    z_99 = &z_99;

    VaR_95_ewma = z_95 * sigma_ewma;
    VaR_99_ewma = z_99 * sigma_ewma;
run;


/*Comparison VAR95%/ VAR99% and Real Returns */
proc sgplot data=var_calc_ewma;
    /* Normal real returns series */
    series x=date y=port_return / 
        lineattrs=(color=blue thickness=1) 
        legendlabel="Real Returns";

    /* VaR 95% */
    series x=date y=VaR_95_ewma / 
        lineattrs=(color=orange pattern=shortdash thickness=2) 
        legendlabel="VaR 95% ewma N";

    /* VaR 99% */
    series x=date y=VaR_99_ewma / 
        lineattrs=(color=red pattern=dot thickness=2) 
        legendlabel="VaR 99% ewma N ";
    xaxis label="Date";
    yaxis label="Returns and VAR(%)";
    title "Comparison VAR95%/ VAR99% and Real Returns (ewma N)";
run;


/*merging  GARCH WITH EWMA */
data var_calc_;
	merge var_calc_ewma(keep= ewma_var z_95 z_99 sigma_ewma var_95_ewma var_99_ewma in=invar_calc_ewma)
	var_calc(keep= resid_t variance_garch_t date port_return port_sq sigma_garch nu z_95_t z_99_t var_95_t var_99_t in=ingarch_plot);
run;


/* Kupiec test */
data backtest_ewma;
    set var_calc_ewma;
    exception_95 = (port_return < VaR_95_ewma);
    exception_99 = (port_return < VaR_99_ewma);

    label_95 = "VaR 95%"; alpha_95 = 0.05; e95 = exception_95;
    label_99 = "VaR 99%"; alpha_99 = 0.01; e99 = exception_99;
run;


proc summary data=backtest_ewma nway;
    output out=kupiec_95(drop=_type_ _freq_)
        sum(e95)=nb_exceptions n(e95)=nb_total;
    output out=kupiec_99(drop=_type_ _freq_)
        sum(e99)=nb_exceptions n(e99)=nb_total;
run;

data kupiec_95; set kupiec_95; alpha=0.05; label="VaR 95%"; run;
data kupiec_99; set kupiec_99; alpha=0.01; label="VaR 99%"; run;

data kupiec_all;
    set kupiec_95 kupiec_99;
    pi = nb_exceptions / nb_total;
    LL0 = nb_exceptions*log(alpha) + (nb_total - nb_exceptions)*log(1 - alpha);
    LL1 = nb_exceptions*log(pi) + (nb_total - nb_exceptions)*log(1 - pi);
    LR_POF = -2 * (LL0 - LL1);
    p_value = 1 - probchi(LR_POF, 1);
run;


/* 3. Sum up information on a chart */
proc print data=kupiec_all label noobs;
    var label nb_exceptions nb_total pi LR_POF p_value;
    label 
        label = "VaR level"
        nb_exceptions = "Number of Exceptions"
        nb_total = "Total number"
        pi = "Observed rate"
        LR_POF = "Kupiec's Statistics"
        p_value = "P-value (H0 : the VaR is accurate )";
    title " Kupiec test – Conditionnal VaR at 95 % and at 99 % (Normal EWMA)";
run;

/* 
VAR95% : 0.34598 
VAR99% : 0.81134 
=> We reject ho, var is accurated for both VAR 95% and VAR 99% 
*/

/* Christoffersen test at 95 % and 99 % */

proc iml;
    use backtest_ewma;
    read all var {exception_95 exception_99} into X;
    close backtest_ewma;

    level = {"VaR 95%", "VaR 99%"};
    result = j(2, 9, .); 

    do k = 1 to 2;
        e = X[,k];
        n = nrow(e);

        /* Initiate counters */
        t00 = 0; t01 = 0; t10 = 0; t11 = 0;

        /*  Count transitions */
        do i = 2 to n;
            if e[i-1]=0 & e[i]=0 then t00 = t00 + 1;
            else if e[i-1]=0 & e[i]=1 then t01 = t01 + 1;
            else if e[i-1]=1 & e[i]=0 then t10 = t10 + 1;
            else if e[i-1]=1 & e[i]=1 then t11 = t11 + 1;
        end;

        /*  Conditional Proba */
        pi0 = t01 / (t00 + t01);
        pi1 = t11 / (t10 + t11);
        pi  = (t01 + t11) / (t00 + t01 + t10 + t11);

        /*  In order to avoid log(0) */
        eps = 1e-10;
        pi0 = max(eps, min(pi0, 1 - eps));
        pi1 = max(eps, min(pi1, 1 - eps));
        pi  = max(eps, min(pi,  1 - eps));

        /*  log likelihood */
        LL0 = (t00 + t10)*log(1 - pi) + (t01 + t11)*log(pi);
        LL1 = t00*log(1 - pi0) + t01*log(pi0) + t10*log(1 - pi1) + t11*log(pi1);

        /*  test and p-value */
        LR = -2 * (LL0 - LL1);
        p = 1 - cdf("chisq", LR, 1);

        /*  results */
        result[k,] = t00 || t01 || t10 || t11 || pi0 || pi1 || LR || p || k;
    end;

    /* Print final results */
    print result[colname={
        "t00" "t01" "t10" "t11" "pi0" "pi1"
        "Stat_Christoffersen" "P_value" "Indice"
    } rowname=level label="Test de Christoffersen – Indépendance des exceptions"];
quit;



/*filtre de kalman*/
proc iml;
use portefeuille_final;
read all var {Date port_return} into data;
close portefeuille_final;

n = nrow(data);
dates = data[,1];
returns = data[,2];

/* Préparation des observations log(r²) globales */
y = j(n, 1, .);
do i = 1 to n;
    if abs(returns[i]) > 1e-8 then 
        y[i] = log(returns[i]##2);
    else 
        y[i] = log(1e-8);
end;

/* === FONCTION KALMAN SIMPLIFIÉE === */
start kalman(var) global(y);
    V = j(nrow(y), 1, 0);      /* Forecast error */
    F = j(nrow(y), 1, 0);      /* Variance forecast error */
    K = j(nrow(y), 1, 0);      /* Kalman gain */
    A = j(nrow(y)+1, 1, 0);    /* One step ahead forecast */
    P = j(nrow(y)+1, 1, 10e7);   /* Variance of the filtered */
    
    /* Initialisation robuste */
    valid_y = y[loc(y ^= .)];
    if ncol(valid_y) > 0 then 
        A[1] = mean(valid_y);
    else 
        A[1] = -5;
    
    do t = 1 to nrow(y);
        v[t] = y[t] - a[t];              /* Innovation */
        f[t] = p[t] + exp(var[2]);       /* var(eps) = R */
        k[t] = p[t] / f[t];              /* Kalman gain */
        a[t+1] = a[t] + k[t] * v[t];     /* État filtré */
        p[t+1] = p[t] * (1-k[t]) + exp(var[1]); /* var(eta) = Q */
    end;
    
    /* Calcul log-vraisemblance */
    loglik = 0;
    do i = 1 to nrow(y);
        if f[i] > 0 then 
            loglik = loglik + log(f[i]) + v[i]*v[i]/f[i];
    end;
    
    ld = -(nrow(y)/2)*log(8*atan(1)) - 0.5*loglik;
    return(ld);
finish kalman;

/* === ESTIMATION DES PARAMÈTRES === */
print "=== ESTIMATION MLE SIMPLIFIÉE ===";
parm = log(0.1) || log(1.0);  /* Initialisation: log(Q) || log(R) */
opt = {1 2};                   /* Options d'optimisation */

call NLPQN(rc, ldv, "kalman", parm, opt);

/* Paramètres optimisés */
var = ldv;
Q_opt = exp(var[1]);  /* Variance processus latent */
R_opt = exp(var[2]);  /* Variance observation */

print "Paramètres optimisés:";
print "Q (var eta):" Q_opt;
print "R (var eps):" R_opt;
print "Log-vraisemblance:" kalman(var);

/* === APPLICATION SIMPLIFIÉE SUR FENÊTRES === */
window = 500;
alpha95 = 1.645;
alpha99 = 2.326;

print "=== APPLICATION DU MODÈLE SV ===";
n_windows = n - window + 1;
final_output = j(n_windows * window, 10, .);
row_idx = 1;

do t = 1 to n_windows;
    window_r = returns[t:t+window-1];
    window_d = dates[t:t+window-1];
    
    /* Préparation observations fenêtre */
    y_window = j(window, 1, .);
    do i = 1 to window;
        if abs(window_r[i]) > 1e-8 then 
            y_window[i] = log(window_r[i]##2);
        else 
            y_window[i] = log(1e-8);
    end;
    
    /* === FILTRAGE AVEC PARAMÈTRES OPTIMISÉS === */
    V = j(window, 1, 0);
    F = j(window, 1, 0);
    K = j(window, 1, 0);
    A = j(window+1, 1, 0);
    P = j(window+1, 1, 10);
    
    /* Initialisation */
    valid_window = y_window[loc(y_window ^= .)];
    if ncol(valid_window) > 0 then 
        A[1] = mean(valid_window);
    else 
        A[1] = -5;
    
    /* Boucle de filtrage */
    do i = 1 to window;
        v[i] = y_window[i] - a[i];
        f[i] = p[i] + R_opt;
        k[i] = p[i] / f[i];
        a[i+1] = a[i] + k[i] * v[i];
        p[i+1] = p[i] * (1-k[i]) + Q_opt;
    end;
    
    /* === LISSAGE SIMPLIFIÉ === */
    alpha = j(window, 1, .);
    r_smooth = j(window, 1, 0);
    
    /* Lissage backward */
    do i = window to 2 by -1;
        r_smooth[i-1] = v[i]/f[i] + (1-k[i])*r_smooth[i];
        alpha[i] = a[i] + p[i] * r_smooth[i-1];
    end;
    alpha[1] = a[1] + p[1] * (v[1]/f[1] + (1-k[1])*r_smooth[1]);
    
    /* === CALCUL VARIANCE ET VAR === */
    do i = 1 to window;
        sigma2 = exp(alpha[i]);
        VaR_95 = alpha95 * sqrt(sigma2);
        VaR_99 = alpha99 * sqrt(sigma2);
        
        /* Prédiction 1 pas en avant */
        if i = window then do;
            sigma2_forecast = exp(alpha[i] + Q_opt/2);
            VaR_95_forecast = alpha95 * sqrt(sigma2_forecast);
            VaR_99_forecast = alpha99 * sqrt(sigma2_forecast);
        end;
        
        /* Stockage */
        final_output[row_idx,1] = t;                    /* Fenetre_ID */
        final_output[row_idx,2] = window_d[i];          /* Date */
        final_output[row_idx,3] = window_r[i];          /* Return */
        final_output[row_idx,4] = y_window[i];          /* log(r²) */
        final_output[row_idx,5] = a[i];                 /* État filtré */
        final_output[row_idx,6] = alpha[i];             /* État lissé */
        final_output[row_idx,7] = sigma2;               /* Variance conditionnelle */
        final_output[row_idx,8] = VaR_95;              /* VaR 95% */
        final_output[row_idx,9] = VaR_99;              /* VaR 99% */
        
        if i = window then 
            final_output[row_idx,10] = VaR_95_forecast; /* VaR forecast */
        else 
            final_output[row_idx,10] = .;
        
        row_idx = row_idx + 1;
    end;
    
    /* Progrès */
    if mod(t, 100) = 0 then 
        print "Fenêtre" t "sur" n_windows "traitée";
end;

/* === CRÉATION DATASET === */
create stochastic_volatility from final_output[
    colname={
        "Fenetre_ID" "Date" "Return" "log_r2" "x_filtered" "x_smoothed" 
        "sigma2_t" "VaR_95" "VaR_99" "VaR_95_forecast"
    }];
append from final_output;
close stochastic_volatility;

/* === STATISTIQUES FINALES === */
print "=== RÉSULTATS FINAUX ===";
print "Paramètres utilisés:";
print "Q (variance eta):" Q_opt;
print "R (variance eps):" R_opt;
print "Nombre d'observations:" (n_windows * window);

/* Stats descriptives */
sigma2_stats = final_output[,7];
sigma2_clean = sigma2_stats[loc(sigma2_stats ^= .)];

if ncol(sigma2_clean) > 0 then do;
    print "Variance conditionnelle moyenne:" mean(sigma2_clean);
    print "Écart-type variance conditionnelle:" std(sigma2_clean);
    print "VaR 95% moyenne:" mean(final_output[loc(final_output[,8] ^= .),8]);
    print "VaR 99% moyenne:" mean(final_output[loc(final_output[,9] ^= .),9]);
end;

/* Export paramètres */
params_final = Q_opt || R_opt;
create sv_params from params_final[colname={"Q_variance" "R_variance"}];
append from params_final;
close sv_params;

quit;

/* === VALIDATION RAPIDE === */
proc means data=stochastic_volatility n mean std min max;
    var sigma2_t VaR_95 VaR_99;
    title "Statistiques du Modèle SV Simplifié";
run;

proc sgplot data=stochastic_volatility (where=(Fenetre_ID <= 3));
    series x=Date y=sigma2_t / group=Fenetre_ID lineattrs=(thickness=2);
    title "Variance Conditionnelle - 3 Premières Fenêtres";
    yaxis label="Variance Conditionnelle";
run;

proc sql;
    create table kupiec_data_kalman as
    select 
        k.Date,
        k.VaR_95,
        k.VaR_99,
        p.port_return,
        (p.port_return < -k.VaR_95) as Violation_95,
        (p.port_return < -k.VaR_99) as Violation_99
    from stochastic_volatility as k
    inner join portefeuille_final as p
    on k.Date = p.Date;
quit;

/*  Calcul brut du test de Kupiec */
data Test_kupiec_kalman;
    set kupiec_data_kalman end=last;
    retain n 0 n_viol_95 0 n_viol_99 0;

    n + 1;
    if Violation_95 = 1 then n_viol_95 + 1;
    if Violation_99 = 1 then n_viol_99 + 1;

    if last then do;
        p_95 = 0.05;
        p_99 = 0.01;
        pi_95 = n_viol_95 / n;
        pi_99 = n_viol_99 / n;

        LR_95 = -2 * ((n_viol_95*log(p_95) + (n - n_viol_95)*log(1 - p_95)) -
                      (n_viol_95*log(pi_95) + (n - n_viol_95)*log(1 - pi_95)));
        LR_99 = -2 * ((n_viol_99*log(p_99) + (n - n_viol_99)*log(1 - p_99)) -
                      (n_viol_99*log(pi_99) + (n - n_viol_99)*log(1 - pi_99)));

        pval_95 = 1 - probchi(LR_95, 1);
        pval_99 = 1 - probchi(LR_99, 1);

        output;
    end;
run;

/* tableau à 2 lignes */
data kupiec_summary;
    set Test_kupiec_kalman;

    /* VaR 95% */
    Niveau_VAR = "VaR 95%";
    Nb_Exceptions = n_viol_95;
    Nb_Total = n;
    Taux_Obs = pi_95;
    Stat_Kupiec = LR_95;
    P_Value = pval_95;
    output;

    /* VaR 99% */
    Niveau_VAR = "VaR 99%";
    Nb_Exceptions = n_viol_99;
    Taux_Obs = pi_99;
    Stat_Kupiec = LR_99;
    P_Value = pval_99;
    output;

    keep Niveau_VAR Nb_Exceptions Nb_Total Taux_Obs Stat_Kupiec P_Value;
run;

/* Affichage du tableau */
title "Test de Kupiec – VaR conditionnelle à 95 % et 99 % (Filtre de Kalman)";
proc print data=kupiec_summary label noobs;
    var Niveau_VAR Nb_Exceptions Nb_Total Taux_Obs Stat_Kupiec P_Value;
    label
        Niveau_VAR = "Niveau de VaR"
        Nb_Exceptions = "Nb Exceptions"
        Nb_Total = "Nb Total"
        Taux_Obs = "Taux observé"
        Stat_Kupiec = "Statistique de Kupiec"
        P_Value = "P-value (H0 : VaR correcte)";
run;



/* violation sur la VaR de Kalman */
proc sql;
    create table christoffersen_data_kalman as
    select 
        k.Date,
        p.port_return,
        (p.port_return < -abs(k.VaR_95)) as exception_95,
        (p.port_return < -abs(k.VaR_99)) as exception_99
    from stochastic_volatility as k
    inner join portefeuille_final as p
    on k.Date = p.Date
    order by k.Date;
quit;

/* Test de Christoffersen  */
proc iml;
    use christoffersen_data_kalman;
    read all var {exception_95 exception_99} into X;
    close christoffersen_data_kalman;

    niveaux = {"VaR 95% (Kalman)", "VaR 99% (Kalman)"};
    result = j(2, 9, .); 

    do k = 1 to 2;
        e = X[,k];
        n = nrow(e);

        /* les compteurs de transitions */
        N00 = 0; N01 = 0; N10 = 0; N11 = 0;

        do i = 2 to n;
            if e[i-1]=0 & e[i]=0 then N00 = N00 + 1;
            else if e[i-1]=0 & e[i]=1 then N01 = N01 + 1;
            else if e[i-1]=1 & e[i]=0 then N10 = N10 + 1;
            else if e[i-1]=1 & e[i]=1 then N11 = N11 + 1;
        end;

        /* Probabilités conditionnelles */
        pi0 = N01 / (N00 + N01);
        pi1 = N11 / (N10 + N11);
        pi  = (N01 + N11) / (N00 + N01 + N10 + N11);

        /* Protection contre log(0) */
        eps = 1e-10;
        pi0 = max(eps, min(pi0, 1 - eps));
        pi1 = max(eps, min(pi1, 1 - eps));
        pi  = max(eps, min(pi,  1 - eps));

        /* Log-vraisemblances */
        LL0 = (N00 + N10)*log(1 - pi) + (N01 + N11)*log(pi);
        LL1 = N00*log(1 - pi0) + N01*log(pi0) + N10*log(1 - pi1) + N11*log(pi1);

        /* Statistique de test */
        LR = -2 * (LL0 - LL1);
        pval = 1 - cdf("chisq", LR, 1);

        /* Enregistrement */
        result[k,] = N00 || N01 || N10 || N11 || pi0 || pi1 || LR || pval || k;
    end;

    print result[colname={
        "N00" "N01" "N10" "N11"
        "Prob(viol|non-viol)" "Prob(viol|viol)"
        "Stat_Christoffersen" "P_value" "Indice"
    } rowname=niveaux label="Test de Christoffersen – Indépendance des violations (Kalman)"];
quit;

