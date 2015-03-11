<master>
<property name="doc(title)">@title;noquote@</property>
<property name="context">@context;noquote@</property>

<h1>@title;noquote@</h1>
<p>
PRETTI algorithm extends the <a href="http://en.wikipedia.org/wiki/Critical_path_method">critical path method</a> (CPM) 
of project management using systems based, statistical network analysis.
</p><p>
This page limits discussion to how PRETTI uses statistics with existing task data.
</p><p>
PRETTI allows for up to three dimensions of tracking critical path: time (duration), cost, and 
eco2 (a sustainable index of a project's choosing).
</p><p>
Each task may provide a minimum, maximum and median value for each dimension.
</p><p>
A PRETTI scenario may set a flag to calculate <a href="http://en.wikipedia.org/wiki/Program_evaluation_and_review_technique#Terminology">expected time</a> (duration) using standard PERT techniques.
</p><p>
CP calculations may be applied to any set of probability points from minimum to maximum value.
</p>
<h2>Generating distribution curves</h2>
<p>
When probability points other than minimum, median and maximum are specified, 
PRETTI generates distribution points based on the standardized normal distribution using a <a href="http://en.wikipedia.org/wiki/Probability_desnity_function">standard probability density function</a> 
and biased according to min, max and median values provided in the data to two standard deviations. 
This works within tollerance for estimating many statical curves including beta distributions 
--based on a suite of tests included with the PRETTI app.
</p><p>
Graph of <a href="http://en.wikipedia.org/wiki/Normal_distribution">Normal distribution</a> equation<br>
<img src="mu-equation-square-axis.png" alt="graph of equation" width="757" height="260">
</p><p>
Where min/median/max estimations are not within tollerance, 
custom distribution sets representing distribution curves may be readily generated by the app using historical performance data. 
</p><p>
Values are estimated by finding the value over the range of distribution at probability point.
</p><p>
Mathematically, consider a set of points X, where each point represents an amount of area under a distribution; 
Y respresents the value over the range of that area (&Delta;X); and pp is the probability point between 0 and 1.
</p><p>
Then, Y at X<sub>i</sub> is Y = f(pp), where:
</p><p>
j is the count of all points in X, and i is n, such that n is the lowest number that satisfies this equation: <br>

<img src="equation1.png" alt="sum for i is 1 to n of x sub i divided by the sum for j is 1 to m of x sub j; this quantity is greater than or equal to the probability point" width="135" height="166">
</p><p>
This algorithm quickly converts historical data into performance data.
</p><p>
Custom statistical curves based on historical performance are nolonger inconvenient to use.
</p>
<p>
For the gritty details, see the procedures acc_fin::pert_omp_to_strict_dc and qaf_y_of_x_dist_curve in this OpenACS package.
</p>



