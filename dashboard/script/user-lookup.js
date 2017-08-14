function findUser(data){
  var results = $.grep(data.data, function(obj){
    var re = new RegExp($("#smithsnet-username").val(), "i");
    return obj.Username.match(re);
  });
  if(results.length === 0){
    $("#danger-alert").text("Username '" + $("#smithsnet-username").val() + "' not found, please try again.");
    $("#danger-alert").show();
    $("#alertpanel").show();
  }
  else if(results.length > 1){
    $("#warning-alert").text(results.length + " matching users found, please refine your search.");
    $("#warning-alert").show();
    $("#alertpanel").show();
  }
  else {
    $("#alertpanel").hide();
    $("#danger-alert").hide();
    $("#warning-alert").hide();
    $("#status-label").text(results[0].Status);
    //$("#clientstatus-label").text(results[0].ClientStatus);
    var bar = $("#status-progress");
    //var clientbar = $("#clientstatus-progress");
    $("#user-displayname").text(results[0].User);
    $("#user-username").text(results[0].Username);
    $("#user-upn").text(results[0].UserPrincipalName);
    $("#user-email").text(results[0].mail);
    $("#user-mailboxtype").text(results[0].MailboxType);
    $("#user-division").text(results[0].Division);
    switch(results[0].Status){
      case "Migrated":
        bar.addClass("progress-bar-success").width("100%");
        break;
      case "Migrated with Errors":
        bar.addClass("progress-bar-warning").width("100%");
        break;
      case "Staged":
        bar.width("67%");
        break;
      case "On-Premises":
        bar.width("33%");
        break;
      default:
        bar.width("25%");
        break;
    }
    /*switch(results[0].ClientStatus){
      case "Not Started":
        clientbar.addClass("progress-bar-disabled").width("100%");
        break;
      case "Installing":
      case "Pending Start":
        clientbar.width("50%");
        break;
      case "Running":
        clientbar.width("75%");
        break;
      case "Failed":
        clientbar.addClass("progress-bar-danger").width("100%");
        break;
      case "Complete":
        clientbar.addClass("progress-bar-success").width("100%");
        break;
    }*/

  }
}


$(function(){
  window.smithsnetusers = $.getJSON("data/account-status.json");
  $("#smithsnet-username").keyup(function(e){
    if(e.which != 13){
      $("#status-label").text("");
      //$("#clientstatus-label").text("");
      $("#user-displayname").text("");
      $("#user-username").text("");
      $("#user-upn").text("");
      $("#user-email").text("");
      $("#user-mailboxtype").text("");
      $("#user-division").text("");
      $("#status-progress").width(0).removeClass("progress-bar-success").removeClass("progress-bar-striped").removeClass("progress-bar-warning").removeClass("progress-bar-danger");
      //$("#clientstatus-progress").width(0).removeClass("progress-bar-disabled").removeClass("progress-bar-success").removeClass("progress-bar-striped").removeClass("progress-bar-warning").removeClass("progress-bar-danger");
    }
  });
  $("#user-lookup").on("submit", function(e){
    e.preventDefault();
    window.smithsnetusers.then(findUser).catch(function(e){
      $("#danger-alert").text("Error loading data");
      $("#danger-alert").show();
      $("#alertpanel").show();
    });
  });
});
