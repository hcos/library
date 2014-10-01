rootURL = "https://rest.cosyverif.io";

url = "";
username = "";
password = "";

function get(url, successFunction, errorFunction)
{
  jQuery.ajax({
    type: 'GET', // Le type de ma requete
    url: rootURL + url, 
    dataType: 'json',
    beforeSend: function (request)
      {
        request.setRequestHeader("Authorization", "Basic  "+ btoa(username + ":" + password) +"==");
      },
    success: successFunction,
    error: errorFunction
  });
}

function post(url, data, successFunction, errorFunction)
{
  jQuery.ajax({
    type: 'POST', // Le type de ma requete
    contentType: 'application/json',
    url: rootURL + url, 
    dataType: 'json',
    data : data,
    beforeSend: function (request)
      {
        request.setRequestHeader("Authorization", "Basic  "+ btoa(username + ":" + password) +"==");
      },
    success: successFunction,
    error: errorFunction
  });
}

function put(url, data, successFunction, errorFunction)
{
  jQuery.ajax({
    type: 'PUT', // Le type de ma requete
    contentType: 'application/json',
    url: rootURL + url, 
    dataType: 'json',
    data : data,
    beforeSend: function (request)
      {
        request.setRequestHeader("Authorization", "Basic  "+ btoa(username + ":" + password) +"==");
      },
    success: successFunction,
    error: errorFunction
  });
}

function del(url, successFunction, errorFunction)
{
  jQuery.ajax({
    type: 'DELETE', // Le type de ma requete
    url: rootURL + url, 
    beforeSend: function (request)
      {
        request.setRequestHeader("Authorization", "Basic  "+ btoa(username + ":" + password) +"==");
      },
    success: successFunction,
    error: errorFunction
  });
}

function loadPage(page)
{
  $('#resource-page').load("html/" + page + ".html");
}

function showMenuItem(element)
{
  $(element).parents("#top-navigation").find('li a[class="active"]').removeClass("active");
  $(element).attr("class","active");
  loadPage($(element).attr("rel"));
  return false;
}
