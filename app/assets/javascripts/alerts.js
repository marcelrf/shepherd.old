var Alerts = (function () {

    var autoCompleteName = function () {
        var button = $("#autocomplete"),
            loading = $("#loading"),
            name = $("#alert_metric_name").val(),
            params = $.param({name: name}),
            url = "/alerts/autocomplete?" + params;

        button.prop("disabled", true);
        loading.html('<img src="http://pinpopular.in/images/spinner_192.gif" />');
        $.get(url, function (data) {
            loading.html('');
            button.prop("disabled", false);
            $("#metric-list").html(data.metrics);
        });
    };

    return {
        "autoCompleteName": autoCompleteName
    };
}());
