import '../models/book.dart';
import '../models/book_file.dart';
import '../utils/book_catalog.dart';
import 'book_file_service.dart';
import 'books_service.dart';

class BookReadAccess {
  final BookItem book;
  final List<BookChapter> chapters;
  final BookChaptersNotApplicable? fileHints;
  final BookReadManifest? manifest;
  final String? error;

  const BookReadAccess({
    required this.book,
    this.chapters = const [],
    this.fileHints,
    this.manifest,
    this.error,
  });

  bool get isFileBook => fileHints != null;
  bool get hasChapters => chapters.isNotEmpty;

  static Future<BookReadAccess> load(BookItem book) async {
    var detail = book;
    String? detailError;
    try {
      detail = await BooksService.getDetail(book);
    } catch (err) {
      detailError = bookChaptersErrorMessage(err, book);
    }

    try {
      final chapters = await BooksService.getChapters(detail);
      return BookReadAccess(
        book: detail,
        chapters: chapters,
        error: chapters.isEmpty ? detailError : null,
      );
    } on BookChaptersNotApplicableException catch (err) {
      return _fileAccess(detail, err.payload);
    } catch (err) {
      if (isFileStyleBook(detail) &&
          (isLegadoSourceMissingError(err) || _looksLikeChaptersRejected(err))) {
        return _fileAccess(
          detail,
          BookChaptersNotApplicable.defaults(
            format: detail.format.isEmpty ? 'epub' : detail.format,
          ),
        );
      }
      return BookReadAccess(
        book: detail,
        error: bookChaptersErrorMessage(err, detail),
      );
    }
  }

  static Future<BookReadAccess> _fileAccess(
    BookItem book,
    BookChaptersNotApplicable hints,
  ) async {
    try {
      final manifest = await BookFileService.getManifest(
        book: book,
        hints: hints,
      );
      return BookReadAccess(
        book: mergeBookDetail(manifest.book, book),
        fileHints: hints,
        manifest: manifest,
      );
    } catch (_) {
      return BookReadAccess(book: book, fileHints: hints);
    }
  }

  static bool _looksLikeChaptersRejected(Object error) {
    final text = error.toString();
    return text.contains('chapters_not_applicable') ||
        text.contains('请求失败:422') ||
        text.contains('请求失败：422');
  }
}
