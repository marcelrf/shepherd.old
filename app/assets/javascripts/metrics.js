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
            generateNameList(data.metrics);
            button.prop("disabled", false);
        });
    };

    var generateNameList = function (metrics) {

//  <div class="control-group">
//    <div class="controls">
//      <input name="metric[name]" type="hidden" value="0"><input id="metric_name" name="metric[name]" type="checkbox" value="1"> Positive
//    </div>
//  </div>

        console.log(metrics);
    };

    return {
        "autoCompleteName": autoCompleteName
    };
}());
