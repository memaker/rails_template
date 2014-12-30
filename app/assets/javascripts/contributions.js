$(function () {
  (function (global, $) {
    var console = global.console
        , setTimeout = global.setTimeout;

    function assert(condition, message) {
      if (condition) return;

      console.log('Assertion Failure: ' + message);
      if (console.trace) console.trace();
      if (Error().stack) console.log(Error().stack);
    }

    function FetchResultTimer(options) {
      this.interval = 2000;
      this.loop_num = 0;
      this.max_loop_num = 10;
      this.current_status = '';

      assert(options['url'], 'specify url to get search result');
      assert(options['container'], 'specify container to set search result');

      this.url = options['url'];
      this.container = options['container'];
    }

    FetchResultTimer.prototype.counting = function (num) {
      var text = '';
      for (var i = 0; i < num - 1; i++)
        text += '.';
      return text
    };

    FetchResultTimer.prototype.fetch_result = function () {
      var me = this;
      $.get(me.url)
          .done(function (json) {
            if (json['message']) {
              if (me.current_status != json['message']) {
                me.loop_num = 0;
                me.current_status = json['message'];
              }

              me.container
                  .html('&nbsp;' + json['message'] + me.counting(me.loop_num))
                  .prepend($('<img src="/assets/img/loading.gif" width="16" height="16" />'));

              me.start();
            } else {
              me.container
                  .empty()
                  .html(json['html']);
            }
          })
          .fail(function () {
            me.container
                .text("I'm sorry, something is wrong. Please retry later.");
          });
    };

    FetchResultTimer.prototype.start = function () {
      var me = this;

      me.loop_num++;
      if (me.loop_num <= me.max_loop_num) {
        setTimeout(function () {
          me.fetch_result();
        }, me.interval * me.loop_num);
      } else {
        me.container
            .text("I'm sorry, something is wrong. Please retry later.");
      }
    };

    global['FetchResultTimer'] = FetchResultTimer;
  })(window, jQuery);
});

