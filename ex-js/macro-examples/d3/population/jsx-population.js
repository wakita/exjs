expression func {
    identifier: d;
    expression: e;
    { _ (d, e) => function (d) { return e; } }
}

expression translate {
    expression: tx, ty;
    literal: s;
    { _ { tx, ty, s } => "translate(" + tx + ", " + ty + ")scale(-1, -1)" }
    { _ { tx, ty } => "translate(" + tx + ", " + ty + ")" }
}


$(function () {
    var width = 960,
    height = 500;

    var x = d3.scale.linear()
        .range([0, width]);

    var y = d3.scale.linear()
        .range([0, height - 40]);

    // An SVG element with a bottom-right origin.
    var svg = d3.select("#chart-macro").append("svg")
        .attr("width", width)
        .attr("height", height)
        .style("padding-right", "30px")
        .append("g")
        .attr("transform", translate { x(1), (height - 20), s });

    // A sliding container to hold the bars.
    var body = svg.append("g")
        .attr("transform", "translate(0,0)");

    // A container to hold the y-axis rules.
    var rules = svg.append("g");

    // A label for the current year.
    var title = svg.append("text")
        .attr("class", "title")
        .attr("dy", ".71em")
        .attr("transform", translate { x(1), y(1), s})
        .text(2000);

    d3.csv("population.csv", function(data) {
        var age0, age1, year0, year1, year, years;
        
        function redraw() {
            if (!(year in data)) return;
            title.text(year);

            body.transition()
                .duration(750)
                .attr("transform", func(d, translate { x(year - year1), 0 }));

            years.selectAll("rect")
                .data(func(d, data[year][d] || [0, 0]))
                .transition()
                .duration(750)
                .attr("height", y);
        }

        // Convert strings to numbers.
        data.forEach(function(d) {
            d.people = +d.people;
            d.year = +d.year;
            d.age = +d.age;
        });

        // Compute the extent of the data set in age and years.
        age0 = 0,
        age1 = d3.max(data, func(d, d.age)),
        year0 = d3.min(data, func(d, d.year)),
        year1 = d3.max(data, func(d, d.year)),
        year = year1;

        // Update the scale domains.
        x.domain([0, age1 + 5]);
        y.domain([0, d3.max(data, func(d, d.people))]);

        // Add rules to show the population values.
        rules = rules.selectAll(".rule")
            .data(y.ticks(10))
            .enter().append("g")
            .attr("class", "rule")
            .attr("transform", func(d, translate { 0, y(d) }));

        rules.append("line")
            .attr("x2", width);

        rules.append("text")
            .attr("x", 6)
            .attr("dy", ".35em")
            .attr("transform", "rotate(180)")
            .text(func(d, Math.round(d / 1e6) + "M"));

        // Add labeled rects for each birthyear.
        years = body.selectAll("g")
            .data(d3.range(year0 - age1, year1 + 5, 5))
            .enter().append("g")
            .attr("transform", func(d, translate { x(year1 - d), 0 }));

        years.selectAll("rect")
            .data(d3.range(2))
            .enter().append("rect")
            .attr("x", 1)
            .attr("width", x(5) - 2)
            .attr("height", 1e-6);

        years.append("text")
            .attr("y", -6)
            .attr("x", -x(5) / 2)
            .attr("transform", "rotate(180)")
            .attr("text-anchor", "middle")
            .style("fill", "#fff")
            .text(String);

        // Add labels to show the age.
        svg.append("g").selectAll("text")
            .data(d3.range(0, age1 + 5, 5))
            .enter().append("text")
            .attr("text-anchor", "middle")
            .attr("transform", func(d, translate { (x(d) + x(5) / 2), -4, s }))
            .attr("dy", ".71em")
            .text(String);

        // Nest by year then birthyear.
        data = d3.nest()
            .key(func(d, d.year))
            .key(func(d, d.year - d.age))
            .rollup(func(v, v.map(func(d, d.people))))
            .map(data);

        // Allow the arrow keys to change the displayed year.
        d3.select(window).on("keydown", function() {
            switch (d3.event.keyCode) {
            case 37: year = Math.max(year0, year - 10); break;
            case 39: year = Math.min(year1, year + 10); break;
            }
            redraw();
        });

        redraw();

        
    });
});