
function displayTos(response) {
jQuery('#terms .modal-body').html(response.replace(/\n/g, "<br />"));
}


function setResponse(method,response) {
	
	
	if (method == "create_user") {
	showSuccess('User created: '+response);

	return true;
	}
	
	if (method == "authenticate") {
	showSuccess('User authentificated: '+response);

	return true;
	}
}

function showError(response) {
jQuery('#response').hide();
jQuery('#response').html('<div id="error" class="alert alert-danger alert-dismissable">\
<button type="button" class="close" data-dismiss="alert" aria-hidden="true">×</button>\
                    <h4><i class="icon fa fa-ban"></i> Error</h4>'+response+'</div>').show();
                

}

function showSuccess(response) {
jQuery('#response').hide();
jQuery('#response').html('<div id="success" class="alert alert-success alert-dismissable">\
<button type="button" class="close" data-dismiss="alert" aria-hidden="true">×</button>\
                    <h4><i class="icon fa fa-check"></i> Success</h4>'+response+'</div>').show();

}




