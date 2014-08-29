$(document).ready(function() {
  $('#time').click(function(e) {
    e.preventDefault();
    // show activity spinner
    $('#spinner').modal({
        backdrop: 'static',
        keyboard: 'false'
      });
    $('#output').load('/time', function(){
      // remove progress notification
      $('#spinner').modal('hide');
    });

  })

  $('#server').click(function(e) {
    e.preventDefault();
    // show activity spinner
    $('#spinner').modal({
        backdrop: 'static',
        keyboard: 'false'
      });
    $('#output').load('/response', function(){
      // remove progress notification
      $('#spinner').modal('hide');
    });
  })

  $('#input').submit(function(e) {
    e.preventDefault();
    // show activity spinner
    $('#spinner').modal({
        backdrop: 'static',
        keyboard: 'false'
      });
    $.ajax({
      type: 'POST',
      url: '/input',
      data: $('#input').serialize(),
      success: function(response){
        $('#output').html(response);
        // initiate the table sorter
        $("#sortable_table").tablesorter( {cssHeader: "header", sortList: [[0,0]]} ); 
        // Initiate the tooltips
        $("[data-toggle='tooltip']").tooltip();
        // remove progress notification
        $('#spinner').modal('hide');
      },
    })
  })
  
  // Handles the form submission when Ctrl+Enter is pressed anywhere on page. adapted from SequenceServer...
  $(document).bind("keydown", function (e) {
    if (e.ctrlKey && e.keyCode === 13 ) {
      $('#input').trigger('submit');
    }
  });




})
