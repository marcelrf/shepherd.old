var Metrics = (function () {

    var autoCompleteName = function () {
        var button = $("#autocomplete"),
            loading = $("#loading"),
            source = $("#metric_source_id").find(":selected").val(),
            name = $("#metric_name").val(),
            params = $.param({source: source, name: name}),
            url = "/metrics/autocomplete?" + params;

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
