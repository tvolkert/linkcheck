library linkcheck.e2e_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dhttpd/dhttpd.dart';
import 'package:linkcheck/linkcheck.dart' show run;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Get the directory of the script being run.
void main() {
  group("linkcheck e2e", () {
    _MockStdout out;
    int port = 4321;

    setUp(() {
      out = _MockStdout();
    });

    tearDown(() {
      out.close();
    });

    test("reports no errors or warnings for a site without issues", () async {
      var server = await Dhttpd.start(path: getServingPath(0), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 0);
        expect(out.output, contains("0 warnings"));
        expect(out.output, contains("0 errors"));
      } finally {
        await server.destroy();
      }
    });

    test("reports no errors or warnings for a site with correct <base>",
        () async {
      var server = await Dhttpd.start(path: getServingPath(4), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 0);
        expect(out.output, contains("0 warnings"));
        expect(out.output, contains("0 errors"));
      } finally {
        await server.destroy();
      }
    });

    test("reports info when link is behind robots.txt rule", () async {
      var server = await Dhttpd.start(path: getServingPath(5), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 0);
        expect(out.output, contains("subdirectory/other.html"));
        expect(out.output, contains("0 warnings"));
        expect(out.output, contains("0 errors"));
      } finally {
        await server.destroy();
      }
    });

    test(
        "reports bad link in file that is disallowed in robots.txt "
        "but allowed for linkcheck", () async {
      var server = await Dhttpd.start(path: getServingPath(11), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 2);
        expect(out.output, contains("non-existent.html"));
        expect(out.output, contains("1 error"));
      } finally {
        await server.destroy();
      }
    });

    group("reports exit code 2 for a site with errors", () {
      test("in CSS", () async {
        var server = await Dhttpd.start(path: getServingPath(1), port: port);
        try {
          int result = await run([":$port"], out);
          expect(result, 2);
          expect(out.output, contains("main.css"));
          expect(out.output, contains("1 error"));
        } finally {
          await server.destroy();
        }
      });

      test("in <link> import", () async {
        var server = await Dhttpd.start(path: getServingPath(2), port: port);
        try {
          int result = await run([":$port"], out);
          expect(result, 2);
          expect(out.output, contains("nonexistent.css"));
          expect(out.output, contains("1 error"));
        } finally {
          await server.destroy();
        }
      });

      test("in <a> to non-existent internal page", () async {
        var server = await Dhttpd.start(path: getServingPath(3), port: port);
        try {
          int result = await run([":$port"], out);
          expect(result, 2);
          expect(out.output, contains("other.html"));
          expect(out.output, contains("nonexistent.html"));
          expect(out.output, contains("1 error"));
        } finally {
          await server.destroy();
        }
      });
    });

    test("reports all missing @font-face sources", () async {
      var server = await Dhttpd.start(path: getServingPath(6), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 2);
        expect(out.output, contains("asset1.eot"));
        expect(out.output, contains("asset2.ttf"));
        expect(out.output, contains("asset3.woff"));
        expect(out.output, contains("asset4.svg"));
      } finally {
        await server.destroy();
      }
    });

    test("allows non-Base64-encoded SVG inline", () async {
      var server = await Dhttpd.start(path: getServingPath(7), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 0);
        expect(out.output, contains("0 warnings"));
        expect(out.output, contains("0 errors"));
      } finally {
        await server.destroy();
      }
    });

    test("skips URLs according to their resolved URL with fragment", () async {
      var server = await Dhttpd.start(path: getServingPath(8), port: port);
      try {
        int result = await run(
            [":$port", "--skip-file", "test/case8/skip-file.txt"], out);
        expect(result, 0);
        expect(out.output, contains("0 warnings"));
        expect(out.output, contains("0 errors"));
      } finally {
        await server.destroy();
      }
    });

    test("skips external URLs according to their resolved URL with fragment",
        () async {
      var server = await Dhttpd.start(path: getServingPath(12), port: port);
      try {
        int result = await run(
            [":$port", "-e", "--skip-file", "test/case12/skip-file.txt"], out);
        expect(result, 0);
        expect(out.output, contains("0 warnings"));
        expect(out.output, contains("0 errors"));
      } finally {
        await server.destroy();
      }
    });

    test("works with unicode in title", () async {
      var server = await Dhttpd.start(path: getServingPath(9), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 0);
      } finally {
        await server.destroy();
      }
    },
        skip: "blocked on package:html bug: "
            "https://github.com/dart-lang/html/issues/70");

    test("anchors are normalized", () async {
      var server = await Dhttpd.start(path: getServingPath(10), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 0);
      } finally {
        await server.destroy();
      }
    });

    test("fragment checking works with non-percent-encoded anchors", () async {
      var server = await Dhttpd.start(path: getServingPath(13), port: port);
      try {
        int result = await run([":$port"], out);
        expect(result, 0);
      } finally {
        await server.destroy();
      }
    });
  }, tags: ["integration"]);
}

var directory = path.absolute(path.dirname(scriptPath));
var scriptPath = scriptUri.toFilePath();

var scriptUri = Platform.script;

String getServingPath(int caseNumber) =>
    path.join(directory, "case$caseNumber");

class _MockStdout implements Stdout {
//  StreamController<List<int>> _controller = new StreamController();
//  StreamSink<List<int>> _sink;

  StringBuffer buf = StringBuffer();

  final Encoding encoding = Encoding.getByName("utf-8");

  _MockStdout() {
//    _sink = _controller.sink;
  }

  Future get done => throw UnimplementedError();

  set encoding(Encoding encoding) {
    throw UnimplementedError();
  }

  bool get hasTerminal => false;

  IOSink get nonBlocking {
    throw UnimplementedError();
  }

  String get output => buf.toString();

  @override
  bool get supportsAnsiEscapes => false;

  int get terminalColumns => 80;

  int get terminalLines => 40;

  void add(List<int> data) {
    throw UnimplementedError();
//    _sink.add(data);
  }

  void addError(error, [StackTrace stackTrace]) {
    throw error;
//    _sink.addError(error, stackTrace);
  }

  Future addStream(Stream<List<int>> stream) => throw UnimplementedError();

  void clearOutput() {
    buf.clear();
  }

  Future close() async {
//    await _sink.close();
//    await _controller.close();
  }

  Future flush() => throw UnimplementedError();

  void write(Object object) {
    String string = '$object';
    buf.write(string);
  }

  void writeAll(Iterable objects, [String sep = ""]) {
    Iterator iterator = objects.iterator;
    if (!iterator.moveNext()) return;
    if (sep.isEmpty) {
      do {
        write(iterator.current);
      } while (iterator.moveNext());
    } else {
      write(iterator.current);
      while (iterator.moveNext()) {
        write(sep);
        write(iterator.current);
      }
    }
  }

  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }

  void writeln([Object object = ""]) {
    write(object);
    write("\n");
  }
}
