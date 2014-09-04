$(document).ready(function() {
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

  function change_adv_params_btn_text(){
    var btn = document.getElementById("adv_params_btn");
    if (btn.text === "&nbsp;&nbsp;Show Advanced Parameters") btn.text = "&nbsp;&nbsp;Hide Advanced Parameters";
    else btn.text = "&nbsp;&nbsp;Show Advanced Parameters";
  }