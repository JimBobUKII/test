function stackedBar(data, title, container, stackMethod){

  if(stackMethod === undefined){
    stackMethod = true;
  }

  google.charts.setOnLoadCallback(function(){
    var d = google.visualization.arrayToDataTable(data);
    var cht = new google.visualization.ChartWrapper({
      chartType: "BarChart",
      dataTable: d,
      options: {
        title: title,
        legend: {
          position: "top",
          maxLines: "3"
        },
        isStacked: stackMethod,
        height: 400
      },
      containerId: container
    });
    cht.draw();
  });
}

