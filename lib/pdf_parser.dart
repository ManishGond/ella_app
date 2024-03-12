import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class MedicalDataExtractor {
  Future<String> extractAllText(List<int> pdfBytes) async {
    try {
      // Load the PDF document
      PdfDocument document = PdfDocument(inputBytes: pdfBytes);

      // Create a new instance of the PdfTextExtractor
      PdfTextExtractor extractor = PdfTextExtractor(document);

      // Extract all the text from the document
      String extractedText = extractor.extractText();

      // Close the document
      document.dispose();

      return extractedText;
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting text: $e');
      }
      return '';
    }
  }
}
