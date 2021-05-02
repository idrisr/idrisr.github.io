---
title: "Regression Differences in R & Python StatsModels"
date: 2014-09-26 15:24
comments: true
published: true
toc: true
---

I'm taking the Coursera Regression
[class](https://www.coursera.org/course/regmods) to keep my skills sharp, and
to get more comfortable using Python for Data Science instead of R. I used to
use R for my data tasks, but it was always a frustrating experience. There are
some things that R definitely does better, such as graphics, but now it's
straightforward to call R from Python for these one-off tasks, while the same
can't be said for calling Python from R.

The Coursera class uses R, so I translate all of the code into Python and
usually get the same result, but not always, and here is one example.

The original point of this example is to show that if you have a linear regression in the form 

$$
Y_i = \beta_0 + \beta_1x_1 + \beta_2x_2 + \beta_3x_3... \beta_nx_n + \epsilon
$$

then if you create another regressor \\(x_j\\) that is a linear combination
of any of the other \\(x_i\\)'s, then you are not adding any new information and
you can throw out the new \\(x_j\\). The technical way to say this is that
the new regressor has perfect collinearity with existing regressors. See this
[article](http://sites.stat.psu.edu/~ajw13/SpecialTopics/multicollinearity.pdf)
for more information on collinearity.

For example, in the `swiss` dataset I create another regressor `z`
that is the linear combination of two of the existing regressors.

R gives a `NA` value for the coefficient of `z`, which is what we expect.

Python's `statsmodels` `ols` method does not recognize that `z` has perfect
collinearity with the other regressors, though there is a warning about the
zero eigenvalue and the strong possibility of multicollinearity.

```
    [1] The smallest eigenvalue is 3.87e-11. This might indicate that there are
    strong multicollinearity problems or that the design matrix is singular.
```

I originally did this work in
[this](http://nbviewer.ipython.org/github/idrisr/coursera-regressions/blob/master/regressions.ipynb)
[IPython notebook](http://ipython.org/notebook.html). In the IPYthon notebook,
there is no warning about the eigenvalues, so you have to be careful to check
for collinearity yourself. Beacuse Python does not elimiate `z`, it also gives
it a \\(\beta\\) value, and therefore some of the \\(\beta\\) values for the other
regressors are also different!

If you're curious for more details, see the
[question](http://stats.stackexchange.com/questions/116825/different-output-for-r-lm-and-python-statsmodel-ols-for-linear-regression)
I posted about this topic on StatsExchange.com.

The table below summarizes the differences and you can see how 3 of the coefficients are different.

{% highlight R %}
| Regressor        | Python statsmodel |    R    |
|------------------|-------------------|---------|
| Intercept        | 66.9152           | 66.9152 |
| Agriculture      |  0.1756           | -0.1721 |
| Catholic         |  0.1041           | -0.2580 |
| Education        | -0.5233           | -0.8709 |
| Examination      | -0.2580           |  0.1041 |
| Infant_Mortality |  1.0770           |  1.0770 |
| z                | -0.3477           |      NA |
{% endhighlight %}

In the end, the lesson is that be sure you need to understand some of the
details of what your stats package is doing. I like the idea of running models
in Python and R, to make sure you get the same answer, and if not, I know then
to investigate further.

{% highlight R %}
data(swiss)
swiss$z <- swiss$Agriculture + swiss$Education
formula <- 'Fertility ~ .'
print(lm(formula, data=swiss))
{% endhighlight %}


{% highlight R %}
Call:
lm(formula = formula, data = swiss)

Coefficients:
     (Intercept)       Agriculture       Examination         Education  
         66.9152           -0.1721           -0.2580           -0.8709  
        Catholic  Infant.Mortality                 z  
          0.1041            1.0770                NA  
{% endhighlight %}

{% highlight Python %}
import statsmodels.formula.api as sm

# load swiss dataset from R
import pandas.rpy.common as com
swiss = com.load_data('swiss')

# get rid of periods in column names
swiss.columns = [_.replace('.', '_') for _ in swiss.columns]

# add clearly duplicative data
swiss['z'] = swiss['Agriculture'] + swiss['Education']

y = 'Fertility'
x = "+".join(swiss.columns - [y])
formula = '%s ~ %s' % (y, x)
print sm.ols(formula, data=swiss).fit().summary()
{% endhighlight  %}

{% highlight Python %}

                            OLS Regression Results                            
==============================================================================
Dep. Variable:              Fertility   R-squared:                       0.707
Model:                            OLS   Adj. R-squared:                  0.671
Method:                 Least Squares   F-statistic:                     19.76
Date:                Thu, 25 Sep 2014   Prob (F-statistic):           5.59e-10
Time:                        22:55:42   Log-Likelihood:                -156.04
No. Observations:                  47   AIC:                             324.1
Df Residuals:                      41   BIC:                             335.2
Df Model:                           5                                         
====================================================================================
                       coef    std err          t      P>|t|      [95.0% Conf. Int.]
------------------------------------------------------------------------------------
Intercept           66.9152     10.706      6.250      0.000        45.294    88.536
Agriculture          0.1756      0.062      2.852      0.007         0.051     0.300
Catholic             0.1041      0.035      2.953      0.005         0.033     0.175
Education           -0.5233      0.115     -4.536      0.000        -0.756    -0.290
Examination         -0.2580      0.254     -1.016      0.315        -0.771     0.255
Infant_Mortality     1.0770      0.382      2.822      0.007         0.306     1.848
z                   -0.3477      0.073     -4.760      0.000        -0.495    -0.200
==============================================================================
Omnibus:                        0.058   Durbin-Watson:                   1.454
Prob(Omnibus):                  0.971   Jarque-Bera (JB):                0.155
Skew:                          -0.077   Prob(JB):                        0.925
Kurtosis:                       2.764   Cond. No.                     1.11e+08
==============================================================================

Warnings:
[1] The smallest eigenvalue is 3.87e-11. This might indicate that there are
strong multicollinearity problems or that the design matrix is singular.
{% endhighlight  %}
