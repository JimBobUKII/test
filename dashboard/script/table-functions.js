function sum(a, b){
  return a + b;
}

function clone(obj) {
  if (!obj || typeof obj != "object") return obj;
  var isAry = Object.prototype.toString.call(obj).toLowerCase() == '[object array]';
  var o = isAry ? [] : {};
  for (var p in obj){
    o[p] = clone(obj[p]);
  }
  return o;
}

// Load the Visualization API and the corechart package.
//var userStatusData = null;
function createTable(destination, data, options){

  var defaultOptions = {
    percentageColumn: true,
    totalColumn: true,
    totalRow: true
  };

  var myOptions = $.extend({}, defaultOptions, options || {});

  var colHeaders = clone(data[0]);
  var tableData = clone(data.slice(1));

  var numDataElements = tableData[0].length;
  if(myOptions.percentageColumn){
    colHeaders.push("% " + colHeaders[numDataElements-1]);
  }
  if(myOptions.totalColumn){
    colHeaders.push("Total");
  }
  var cols = [];
  colHeaders.forEach(function(el){
    cols.push({title: el});
  });
  var numCols = colHeaders.length;
  var totalrow = Array.apply(null, Array(numCols)).map(Number.prototype.valueOf, 0);
  totalrow[0] = "Total";
  tableData.forEach(function(cells, rowidx){
    var rowTotal = 0;
    cells.forEach(function(cell, colidx){
      if(colidx > 0){
        rowTotal += cell;
        totalrow[colidx] += cell;
        totalrow[numCols-1] += cell;
      }
    });
    if(myOptions.percentageColumn){
      tableData[rowidx].push(Math.round(1000 * tableData[rowidx][numDataElements-1] / rowTotal)/10 + "%");
    }
    if(myOptions.totalColumn){
      tableData[rowidx].push(rowTotal);
    }
  });
  if(myOptions.percentageColumn){
    totalrow[numCols-2] = Math.round(1000 * totalrow[numCols-3] / totalrow[numCols-1])/10 + "%";
  }
  if(myOptions.totalRow){
    tableData.push(totalrow);
  }

  var dt = destination.DataTable({
    data: tableData,
    columns: cols,
    paging: false,
    ordering: false,
    info: false,
    searching: false
  });
  dt.draw();
}

