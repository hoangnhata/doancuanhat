package com.expense.service;

import com.expense.entity.Transaction;
import com.expense.entity.User;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.TransactionRepository;
import com.lowagie.text.Document;
import com.lowagie.text.DocumentException;
import com.lowagie.text.Element;
import com.lowagie.text.Font;
import com.lowagie.text.PageSize;
import com.lowagie.text.Paragraph;
import com.lowagie.text.Phrase;
import com.lowagie.text.Rectangle;
import com.lowagie.text.pdf.BaseFont;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfPageEventHelper;
import com.lowagie.text.pdf.PdfWriter;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.DataFormat;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.PrintSetup;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.VerticalAlignment;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFCell;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFRow;
import org.apache.poi.xssf.usermodel.XSSFSheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ExportService {

    private static final Logger log = LoggerFactory.getLogger(ExportService.class);
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter DATETIME_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final String FONT_PATH = "/fonts/NotoSans-Regular.ttf";

    private static final byte[] RGB_PRIMARY = {(byte) 0x02, (byte) 0x88, (byte) 0xD1};
    private static final byte[] RGB_PRIMARY_LIGHT = {(byte) 0xE0, (byte) 0xF2, (byte) 0xFE};
    private static final byte[] RGB_ROW_ALT = {(byte) 0xF8, (byte) 0xFA, (byte) 0xFC};
    private static final byte[] RGB_EXPENSE = {(byte) 0xFE, (byte) 0xE2, (byte) 0xE2};
    private static final byte[] RGB_INCOME = {(byte) 0xDC, (byte) 0xFC, (byte) 0xE7};
    private static final byte[] RGB_TEXT = {(byte) 0x0F, (byte) 0x17, (byte) 0x2A};
    private static final byte[] RGB_MUTED = {(byte) 0x64, (byte) 0x74, (byte) 0x8B};

    private final TransactionRepository transactionRepository;
    private final UserService userService;

    @Transactional(readOnly = true)
    public byte[] exportExcel(LocalDate startDate, LocalDate endDate) throws IOException {
        User user = userService.getCurrentUserEntity();
        List<Transaction> transactions = transactionRepository.findByUserIdAndTransactionDateBetweenAll(
                user.getId(), startDate, endDate);

        double totalExp = sumExpense(transactions);
        double totalInc = sumIncome(transactions);
        double balance = totalInc - totalExp;

        try (XSSFWorkbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            ExcelStyles styles = new ExcelStyles(workbook);

            buildMainSheet(workbook, styles, user, startDate, endDate, transactions, totalExp, totalInc, balance);
            buildCategorySheet(workbook, styles, transactions, totalExp, totalInc);

            workbook.write(out);
            return out.toByteArray();
        }
    }

    private void buildMainSheet(
            XSSFWorkbook workbook,
            ExcelStyles styles,
            User user,
            LocalDate startDate,
            LocalDate endDate,
            List<Transaction> transactions,
            double totalExp,
            double totalInc,
            double balance) {

        XSSFSheet sheet = workbook.createSheet("Báo cáo");
        sheet.setDisplayGridlines(false);
        sheet.setTabColor(new XSSFColor(RGB_PRIMARY, null));
        final int lastCol = 6; // A-G

        int rowNum = 0;

        rowNum = writeBrandBanner(sheet, rowNum, lastCol, "EXPENSE MANAGER  •  Báo cáo tài chính cá nhân", styles.brandBanner);
        rowNum = writeMergedTitle(sheet, rowNum, lastCol, "Báo cáo giao dịch chi tiết", styles.titleReport);
        rowNum = writeMergedSubtitle(sheet, rowNum, lastCol,
                "Kỳ báo cáo: " + startDate.format(DATE_FORMAT) + "  —  " + endDate.format(DATE_FORMAT), styles.subtitle);
        rowNum = writeMergedSubtitle(sheet, rowNum, lastCol,
                "Người dùng: " + safe(user.getFullName()) + "  •  " + safe(user.getEmail()), styles.subtitle);
        rowNum = writeMergedSubtitle(sheet, rowNum, lastCol,
                "Số giao dịch: " + transactions.size() + "  •  Xuất lúc: " + LocalDateTime.now().format(DATETIME_FORMAT),
                styles.subtitle);
        rowNum++;

        rowNum = writeKpiRow(sheet, rowNum, styles, totalExp, totalInc, balance);
        rowNum += 2;

        String[] headers = {"STT", "Ngày", "Loại", "Số tiền (₫)", "Danh mục", "Ví", "Mô tả"};
        XSSFRow headerRow = sheet.createRow(rowNum++);
        headerRow.setHeightInPoints(22);
        for (int i = 0; i < headers.length; i++) {
            XSSFCell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(styles.tableHeader);
        }

        int stt = 1;
        int headerRowNum = headerRow.getRowNum();
        for (Transaction t : transactions) {
            XSSFRow row = sheet.createRow(rowNum++);
            row.setHeightInPoints(20);
            boolean alt = stt % 2 == 0;
            boolean expense = t.getType() == TransactionType.EXPENSE;
            XSSFCellStyle rowStyle = alt ? styles.rowAlt : styles.rowBase;
            XSSFCellStyle rowStyleWrap = alt ? styles.rowAltWrap : styles.rowBaseWrap;
            XSSFCellStyle typeStyle = expense ? styles.typeExpense : styles.typeIncome;

            createStyledCell(row, 0, stt++, rowStyle, HorizontalAlignment.CENTER);
            createStyledCell(row, 1, t.getTransactionDate().format(DATE_FORMAT), rowStyle, HorizontalAlignment.CENTER);
            createStyledCell(row, 2, expense ? "Chi phí" : "Thu nhập", typeStyle, HorizontalAlignment.CENTER);

            XSSFCell amountCell = row.createCell(3);
            amountCell.setCellValue(t.getAmount().doubleValue());
            amountCell.setCellStyle(expense ? styles.moneyExpense : styles.moneyIncome);

            createStyledCell(row, 4, t.getCategory().getName(), rowStyle, HorizontalAlignment.LEFT);
            createStyledCell(row, 5, walletName(t), rowStyle, HorizontalAlignment.LEFT);

            XSSFCell descCell = row.createCell(6);
            descCell.setCellValue(blankToDash(t.getDescription()));
            descCell.setCellStyle(rowStyleWrap);
        }

        if (!transactions.isEmpty()) {
            rowNum = writeTransactionTotals(sheet, rowNum, styles, transactions, totalExp, totalInc);
        }

        if (transactions.isEmpty()) {
            XSSFRow emptyRow = sheet.createRow(rowNum++);
            XSSFCell emptyCell = emptyRow.createCell(0);
            emptyCell.setCellValue("Không có giao dịch trong kỳ này.");
            emptyCell.setCellStyle(styles.subtitle);
            sheet.addMergedRegion(new CellRangeAddress(emptyRow.getRowNum(), emptyRow.getRowNum(), 0, lastCol));
        }

        rowNum++;
        writeMergedSubtitle(sheet, rowNum, lastCol,
                "Báo cáo được tạo tự động từ Expense Manager — dữ liệu mang tính tham khảo tại thời điểm xuất.",
                styles.footer);

        sheet.createFreezePane(0, headerRowNum + 1);
        if (!transactions.isEmpty()) {
            sheet.setAutoFilter(new CellRangeAddress(headerRowNum, rowNum - 2, 0, lastCol));
        }

        configurePrint(sheet, headerRowNum, rowNum - 1);

        int[] widths = {2200, 3400, 3800, 4800, 5200, 4200, 9000};
        for (int i = 0; i < widths.length; i++) {
            sheet.setColumnWidth(i, widths[i]);
        }
    }

    private void buildCategorySheet(
            XSSFWorkbook workbook,
            ExcelStyles styles,
            List<Transaction> transactions,
            double totalExp,
            double totalInc) {

        XSSFSheet sheet = workbook.createSheet("Theo danh mục");
        sheet.setDisplayGridlines(false);
        sheet.setTabColor(new XSSFColor(new byte[]{(byte) 0x0E, (byte) 0xA5, (byte) 0xE9}, null));

        Map<String, CategoryAgg> expenseMap = aggregateByCategory(transactions, TransactionType.EXPENSE);
        Map<String, CategoryAgg> incomeMap = aggregateByCategory(transactions, TransactionType.INCOME);

        int rowNum = 0;
        rowNum = writeMergedTitle(sheet, rowNum, 4, "Phân tích theo danh mục", styles.titleReport);
        rowNum++;

        rowNum = writeCategoryBlock(sheet, rowNum, styles, "Chi phí theo danh mục", expenseMap, totalExp);
        rowNum += 2;
        writeCategoryBlock(sheet, rowNum, styles, "Thu nhập theo danh mục", incomeMap, totalInc);

        for (int i = 0; i < 5; i++) {
            sheet.setColumnWidth(i, i == 0 ? 7200 : 4200);
        }
    }

    private int writeCategoryBlock(
            XSSFSheet sheet,
            int rowNum,
            ExcelStyles styles,
            String blockTitle,
            Map<String, CategoryAgg> map,
            double grandTotal) {

        XSSFRow titleRow = sheet.createRow(rowNum++);
        XSSFCell titleCell = titleRow.createCell(0);
        titleCell.setCellValue(blockTitle);
        titleCell.setCellStyle(styles.sectionTitle);
        sheet.addMergedRegion(new CellRangeAddress(titleRow.getRowNum(), titleRow.getRowNum(), 0, 4));

        String[] headers = {"Danh mục", "Số GD", "Tổng tiền (₫)", "Tỷ lệ (%)"};
        XSSFRow headerRow = sheet.createRow(rowNum++);
        for (int i = 0; i < headers.length; i++) {
            XSSFCell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(styles.tableHeader);
        }

        if (map.isEmpty()) {
            XSSFRow empty = sheet.createRow(rowNum++);
            XSSFCell c = empty.createCell(0);
            c.setCellValue("Không có dữ liệu");
            c.setCellStyle(styles.subtitle);
            sheet.addMergedRegion(new CellRangeAddress(empty.getRowNum(), empty.getRowNum(), 0, 3));
            return rowNum;
        }

        List<Map.Entry<String, CategoryAgg>> sorted = new ArrayList<>(map.entrySet());
        sorted.sort(Comparator.comparingDouble((Map.Entry<String, CategoryAgg> e) -> e.getValue().total).reversed());

        int idx = 1;
        for (Map.Entry<String, CategoryAgg> entry : sorted) {
            CategoryAgg agg = entry.getValue();
            double pct = grandTotal > 0 ? (agg.total / grandTotal) * 100 : 0;
            XSSFRow row = sheet.createRow(rowNum++);
            XSSFCellStyle rowStyle = idx % 2 == 0 ? styles.rowAlt : styles.rowBase;

            createStyledCell(row, 0, entry.getKey(), rowStyle, HorizontalAlignment.LEFT);
            createStyledCell(row, 1, agg.count, rowStyle, HorizontalAlignment.CENTER);

            XSSFCell moneyCell = row.createCell(2);
            moneyCell.setCellValue(agg.total);
            moneyCell.setCellStyle(styles.moneyNeutral);

            XSSFCell pctCell = row.createCell(3);
            pctCell.setCellValue(Math.round(pct * 10) / 10.0);
            pctCell.setCellStyle(styles.percent);
            idx++;
        }

        XSSFRow totalRow = sheet.createRow(rowNum++);
        createStyledCell(totalRow, 0, "Tổng cộng", styles.tableHeader, HorizontalAlignment.LEFT);
        createStyledCell(totalRow, 1, sorted.stream().mapToInt(e -> e.getValue().count).sum(), styles.tableHeader, HorizontalAlignment.CENTER);
        XSSFCell totalMoney = totalRow.createCell(2);
        totalMoney.setCellValue(grandTotal);
        totalMoney.setCellStyle(styles.tableHeader);
        createStyledCell(totalRow, 3, grandTotal > 0 ? 100.0 : 0.0, styles.tableHeader, HorizontalAlignment.CENTER);

        return rowNum;
    }

    private int writeBrandBanner(XSSFSheet sheet, int rowNum, int lastCol, String text, XSSFCellStyle style) {
        XSSFRow row = sheet.createRow(rowNum);
        XSSFCell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(style);
        sheet.addMergedRegion(new CellRangeAddress(rowNum, rowNum, 0, lastCol));
        row.setHeightInPoints(28);
        return rowNum + 1;
    }

    private int writeTransactionTotals(
            XSSFSheet sheet,
            int rowNum,
            ExcelStyles styles,
            List<Transaction> transactions,
            double totalExp,
            double totalInc) {

        long expCount = transactions.stream().filter(t -> t.getType() == TransactionType.EXPENSE).count();
        long incCount = transactions.stream().filter(t -> t.getType() == TransactionType.INCOME).count();

        rowNum = writeTotalLine(sheet, rowNum, styles, "Tổng chi phí", expCount, totalExp, styles.moneyExpense);
        rowNum = writeTotalLine(sheet, rowNum, styles, "Tổng thu nhập", incCount, totalInc, styles.moneyIncome);

        XSSFRow balanceRow = sheet.createRow(rowNum++);
        balanceRow.setHeightInPoints(22);
        sheet.addMergedRegion(new CellRangeAddress(balanceRow.getRowNum(), balanceRow.getRowNum(), 0, 2));
        createStyledCell(balanceRow, 0, "Chênh lệch (Thu − Chi)", styles.tableHeader, HorizontalAlignment.RIGHT);

        double balance = totalInc - totalExp;
        XSSFCell balanceCell = balanceRow.createCell(3);
        balanceCell.setCellValue(balance);
        balanceCell.setCellStyle(balance >= 0 ? styles.kpiPositiveAmount : styles.kpiNegativeAmount);

        sheet.addMergedRegion(new CellRangeAddress(balanceRow.getRowNum(), balanceRow.getRowNum(), 4, 6));
        XSSFCell padCell = balanceRow.createCell(4);
        padCell.setCellStyle(styles.tableHeader);

        return rowNum;
    }

    private int writeTotalLine(
            XSSFSheet sheet,
            int rowNum,
            ExcelStyles styles,
            String label,
            long count,
            double total,
            XSSFCellStyle moneyStyle) {

        XSSFRow row = sheet.createRow(rowNum++);
        row.setHeightInPoints(20);
        sheet.addMergedRegion(new CellRangeAddress(row.getRowNum(), row.getRowNum(), 0, 2));
        createStyledCell(row, 0, label + " (" + count + " GD)", styles.tableHeader, HorizontalAlignment.RIGHT);

        XSSFCell moneyCell = row.createCell(3);
        moneyCell.setCellValue(total);
        moneyCell.setCellStyle(moneyStyle);

        sheet.addMergedRegion(new CellRangeAddress(row.getRowNum(), row.getRowNum(), 4, 6));
        XSSFCell padCell = row.createCell(4);
        padCell.setCellStyle(styles.tableHeader);
        return rowNum;
    }

    private void configurePrint(Sheet sheet, int headerRowNum, int lastContentRow) {
        PrintSetup printSetup = sheet.getPrintSetup();
        printSetup.setLandscape(true);
        printSetup.setFitWidth((short) 1);
        printSetup.setFitHeight((short) 0);
        sheet.setFitToPage(true);
        sheet.setAutobreaks(true);
        sheet.setRepeatingRows(CellRangeAddress.valueOf((headerRowNum + 1) + ":" + (headerRowNum + 1)));
        sheet.setMargin(Sheet.LeftMargin, 0.4);
        sheet.setMargin(Sheet.RightMargin, 0.4);
        sheet.setMargin(Sheet.TopMargin, 0.5);
        sheet.setMargin(Sheet.BottomMargin, 0.5);
        if (lastContentRow > headerRowNum) {
            sheet.setPrintGridlines(false);
            workbookSetPrintArea(sheet, lastContentRow);
        }
    }

    private void workbookSetPrintArea(Sheet sheet, int lastRow) {
        sheet.getWorkbook().setPrintArea(sheet.getWorkbook().getSheetIndex(sheet), 0, 6, 0, lastRow);
    }

    private int writeKpiRow(XSSFSheet sheet, int rowNum, ExcelStyles styles, double totalExp, double totalInc, double balance) {
        String[] labels = {"Tổng chi phí", "Tổng thu nhập", "Chênh lệch"};
        String[] values = {formatMoneyVnd(totalExp), formatMoneyVnd(totalInc), formatMoneyVnd(balance)};
        XSSFCellStyle[] kpiStyles = {styles.kpiExpense, styles.kpiIncome, balance >= 0 ? styles.kpiPositive : styles.kpiNegative};
        int[][] spans = {{0, 2}, {3, 4}, {5, 6}};

        XSSFRow row = sheet.createRow(rowNum);
        for (int i = 0; i < 3; i++) {
            XSSFCell cell = row.createCell(spans[i][0]);
            cell.setCellValue(labels[i] + "\n" + values[i]);
            cell.setCellStyle(kpiStyles[i]);
            sheet.addMergedRegion(new CellRangeAddress(rowNum, rowNum, spans[i][0], spans[i][1]));
        }
        row.setHeightInPoints(48);
        return rowNum + 1;
    }

    private int writeMergedTitle(XSSFSheet sheet, int rowNum, int lastCol, String text, XSSFCellStyle style) {
        XSSFRow row = sheet.createRow(rowNum);
        XSSFCell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(style);
        sheet.addMergedRegion(new CellRangeAddress(rowNum, rowNum, 0, lastCol));
        row.setHeightInPoints(style == null ? 18 : 22);
        return rowNum + 1;
    }

    private int writeMergedSubtitle(XSSFSheet sheet, int rowNum, int lastCol, String text, XSSFCellStyle style) {
        XSSFRow row = sheet.createRow(rowNum);
        XSSFCell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(style);
        sheet.addMergedRegion(new CellRangeAddress(rowNum, rowNum, 0, lastCol));
        return rowNum + 1;
    }

    private void createStyledCell(XSSFRow row, int col, Object value, XSSFCellStyle style, HorizontalAlignment align) {
        XSSFCell cell = row.createCell(col);
        if (value instanceof Number n) {
            cell.setCellValue(n.doubleValue());
        } else {
            cell.setCellValue(String.valueOf(value));
        }
        cell.setCellStyle(style);
    }

    /**
     * Báo cáo PDF: header thương hiệu, KPI, bảng theo danh mục, chi tiết giao dịch, chân trang có số trang.
     */
    @Transactional(readOnly = true)
    public byte[] exportPdf(LocalDate startDate, LocalDate endDate) throws IOException, DocumentException {
        User user = userService.getCurrentUserEntity();
        List<Transaction> transactions = transactionRepository.findByUserIdAndTransactionDateBetweenAll(
                user.getId(), startDate, endDate);

        BaseFont bf = loadBaseFont();

        Color accentBlue = new Color(0x02, 0x88, 0xD1);
        Color textDark = new Color(0x0F, 0x17, 0x2A);
        Color textMuted = new Color(0x64, 0x74, 0x8B);
        Color expenseRed = new Color(0xDC, 0x26, 0x26);
        Color incomeGreen = new Color(0x16, 0xA3, 0x4A);
        Color rowAlt = new Color(0xF8, 0xFA, 0xFC);

        Font titleFont = new Font(bf, 22, Font.BOLD, accentBlue);
        Font brandFont = new Font(bf, 10, Font.BOLD, accentBlue);
        Font subtitleFont = new Font(bf, 10, Font.NORMAL, textMuted);
        Font sectionFont = new Font(bf, 12, Font.BOLD, textDark);
        Font headerFont = new Font(bf, 9, Font.BOLD, Color.WHITE);
        Font cellFont = new Font(bf, 8, Font.NORMAL, textDark);
        Font cellBold = new Font(bf, 8, Font.BOLD, textDark);
        Font footerFont = new Font(bf, 8, Font.ITALIC, textMuted);

        double totalExp = sumExpense(transactions);
        double totalInc = sumIncome(transactions);
        double balance = totalInc - totalExp;

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Document document = new Document(PageSize.A4, 42, 42, 50, 52);
        PdfWriter writer = PdfWriter.getInstance(document, baos);
        writer.setPageEvent(new PdfFooterEvent(bf, footerFont, accentBlue));
        document.open();

        addPdfHeaderBar(document, accentBlue);

        Paragraph brand = new Paragraph("EXPENSE MANAGER", brandFont);
        brand.setAlignment(Element.ALIGN_CENTER);
        brand.setSpacingAfter(4);
        document.add(brand);

        Paragraph title = new Paragraph("Báo cáo giao dịch", titleFont);
        title.setAlignment(Element.ALIGN_CENTER);
        title.setSpacingAfter(6);
        document.add(title);

        document.add(centeredParagraph(
                "Kỳ: " + startDate.format(DATE_FORMAT) + "  —  " + endDate.format(DATE_FORMAT), subtitleFont));
        document.add(centeredParagraph(
                safe(user.getFullName()) + "  •  " + safe(user.getEmail()), subtitleFont));
        document.add(centeredParagraph(
                "Số giao dịch: " + transactions.size() + "  •  Xuất lúc: "
                        + LocalDateTime.now().format(DATETIME_FORMAT), subtitleFont, 18));

        PdfPTable kpi = new PdfPTable(3);
        kpi.setWidthPercentage(100);
        kpi.setWidths(new float[]{1f, 1f, 1f});
        kpi.setSpacingAfter(16);
        addKpiCell(kpi, "Tổng chi phí", formatMoneyVnd(totalExp), expenseRed, expenseRed, bf, rowAlt);
        addKpiCell(kpi, "Tổng thu nhập", formatMoneyVnd(totalInc), incomeGreen, incomeGreen, bf, rowAlt);
        addKpiCell(kpi, "Chênh lệch", formatMoneyVnd(balance), accentBlue, balance >= 0 ? incomeGreen : expenseRed, bf, rowAlt);
        document.add(kpi);

        addCategorySummaryPdf(document, transactions, totalExp, totalInc, bf, sectionFont, headerFont, cellFont,
                accentBlue, rowAlt, expenseRed, incomeGreen, new Color(0xE2, 0xE8, 0xF0));

        Paragraph tableTitle = new Paragraph("Chi tiết giao dịch", sectionFont);
        tableTitle.setSpacingAfter(8);
        document.add(tableTitle);

        PdfPTable table = new PdfPTable(6);
        table.setWidthPercentage(100);
        table.setWidths(new float[]{1.1f, 0.9f, 1.2f, 1.3f, 1f, 2.2f});
        table.setHeaderRows(1);
        table.setSplitLate(false);

        Color borderGray = new Color(0xE2, 0xE8, 0xF0);

        String[] headers = {"Ngày", "Loại", "Số tiền (₫)", "Danh mục", "Ví", "Mô tả"};
        for (String h : headers) {
            PdfPCell hc = borderedCell(new Phrase(h, headerFont), accentBlue, Element.ALIGN_CENTER, borderGray);
            hc.setPadding(8);
            table.addCell(hc);
        }

        int row = 0;
        for (Transaction t : transactions) {
            Color bg = row % 2 == 0 ? Color.WHITE : rowAlt;
            boolean expense = t.getType() == TransactionType.EXPENSE;
            String type = expense ? "Chi phí" : "Thu nhập";
            Font typeFont = new Font(bf, 8, Font.BOLD, expense ? expenseRed : incomeGreen);
            Font amountFont = new Font(bf, 8, Font.BOLD, expense ? expenseRed : incomeGreen);

            addTableCell(table, t.getTransactionDate().format(DATE_FORMAT), cellFont, Element.ALIGN_CENTER, bg, borderGray);
            addTableCell(table, type, typeFont, Element.ALIGN_CENTER, bg, borderGray);
            addTableCell(table, formatMoneyVndPlain(t.getAmount().doubleValue()), amountFont, Element.ALIGN_RIGHT, bg, borderGray);
            addTableCell(table, t.getCategory().getName(), cellFont, Element.ALIGN_LEFT, bg, borderGray);
            addTableCell(table, walletName(t), cellFont, Element.ALIGN_LEFT, bg, borderGray);
            addTableCell(table, blankToDash(t.getDescription()), cellFont, Element.ALIGN_LEFT, bg, borderGray);
            row++;
        }

        if (!transactions.isEmpty()) {
            addPdfTransactionTotals(table, transactions, totalExp, totalInc, bf, headerFont, cellBold, expenseRed, incomeGreen, accentBlue, borderGray);
        }

        if (transactions.isEmpty()) {
            PdfPCell empty = borderedCell(
                    new Phrase("Không có giao dịch trong kỳ này.", new Font(bf, 9, Font.ITALIC, textMuted)),
                    rowAlt, Element.ALIGN_CENTER, borderGray);
            empty.setColspan(6);
            empty.setPadding(18);
            table.addCell(empty);
        }

        document.add(table);

        Paragraph disclaimer = new Paragraph(
                "Báo cáo được tạo tự động từ Expense Manager. Số liệu phản ánh trạng thái tại thời điểm xuất và mang tính tham khảo.",
                footerFont);
        disclaimer.setAlignment(Element.ALIGN_CENTER);
        disclaimer.setSpacingBefore(16);
        document.add(disclaimer);
        document.close();
        return baos.toByteArray();
    }

    private void addCategorySummaryPdf(
            Document document,
            List<Transaction> transactions,
            double totalExp,
            double totalInc,
            BaseFont bf,
            Font sectionFont,
            Font headerFont,
            Font cellFont,
            Color accentBlue,
            Color rowAlt,
            Color expenseRed,
            Color incomeGreen,
            Color borderGray) throws DocumentException {

        Map<String, CategoryAgg> expenseMap = aggregateByCategory(transactions, TransactionType.EXPENSE);
        Map<String, CategoryAgg> incomeMap = aggregateByCategory(transactions, TransactionType.INCOME);
        if (expenseMap.isEmpty() && incomeMap.isEmpty()) {
            return;
        }

        if (!expenseMap.isEmpty()) {
            Paragraph section = new Paragraph("Tóm tắt theo danh mục (chi phí)", sectionFont);
            section.setSpacingAfter(8);
            document.add(section);

            PdfPTable catTable = new PdfPTable(4);
            catTable.setWidthPercentage(100);
            catTable.setWidths(new float[]{2.2f, 0.8f, 1.2f, 0.8f});
            catTable.setSpacingAfter(14);

            for (String h : new String[]{"Danh mục", "Số GD", "Tổng (₫)", "%"}) {
                PdfPCell hc = borderedCell(new Phrase(h, headerFont), accentBlue, Element.ALIGN_CENTER, borderGray);
                hc.setPadding(7);
                catTable.addCell(hc);
            }

            addCategoryRowsPdf(catTable, expenseMap, totalExp, bf, cellFont, rowAlt, expenseRed, borderGray);
            document.add(catTable);
        }

        if (!incomeMap.isEmpty()) {
            Paragraph incSection = new Paragraph("Tóm tắt theo danh mục (thu nhập)", sectionFont);
            incSection.setSpacingAfter(8);
            document.add(incSection);

            PdfPTable incTable = new PdfPTable(4);
            incTable.setWidthPercentage(100);
            incTable.setWidths(new float[]{2.2f, 0.8f, 1.2f, 0.8f});
            incTable.setSpacingAfter(16);
            for (String h : new String[]{"Danh mục", "Số GD", "Tổng (₫)", "%"}) {
                PdfPCell hc = borderedCell(new Phrase(h, headerFont), accentBlue, Element.ALIGN_CENTER, borderGray);
                hc.setPadding(7);
                incTable.addCell(hc);
            }
            addCategoryRowsPdf(incTable, incomeMap, totalInc, bf, cellFont, rowAlt, incomeGreen, borderGray);
            document.add(incTable);
        }
    }

    private void addCategoryRowsPdf(
            PdfPTable table,
            Map<String, CategoryAgg> map,
            double grandTotal,
            BaseFont bf,
            Font cellFont,
            Color rowAlt,
            Color accentColor,
            Color borderGray) {

        List<Map.Entry<String, CategoryAgg>> sorted = new ArrayList<>(map.entrySet());
        sorted.sort(Comparator.comparingDouble((Map.Entry<String, CategoryAgg> e) -> e.getValue().total).reversed());

        int i = 0;
        for (Map.Entry<String, CategoryAgg> entry : sorted) {
            CategoryAgg agg = entry.getValue();
            double pct = grandTotal > 0 ? (agg.total / grandTotal) * 100 : 0;
            Color bg = i % 2 == 0 ? Color.WHITE : rowAlt;
            addTableCell(table, entry.getKey(), cellFont, Element.ALIGN_LEFT, bg, borderGray);
            addTableCell(table, String.valueOf(agg.count), cellFont, Element.ALIGN_CENTER, bg, borderGray);
            addTableCell(table, formatMoneyVndPlain(agg.total), new Font(bf, 8, Font.BOLD, accentColor), Element.ALIGN_RIGHT, bg, borderGray);
            addTableCell(table, String.format(Locale.forLanguageTag("vi-VN"), "%.1f%%", pct), cellFont, Element.ALIGN_CENTER, bg, borderGray);
            i++;
        }
    }

    private void addPdfTransactionTotals(
            PdfPTable table,
            List<Transaction> transactions,
            double totalExp,
            double totalInc,
            BaseFont bf,
            Font headerFont,
            Font cellBold,
            Color expenseRed,
            Color incomeGreen,
            Color accentBlue,
            Color borderGray) {

        long expCount = transactions.stream().filter(t -> t.getType() == TransactionType.EXPENSE).count();
        long incCount = transactions.stream().filter(t -> t.getType() == TransactionType.INCOME).count();
        double balance = totalInc - totalExp;

        addPdfTotalRow(table, "Tổng chi phí (" + expCount + " GD)", formatMoneyVndPlain(totalExp),
                new Font(bf, 8, Font.BOLD, expenseRed), headerFont, accentBlue, borderGray);
        addPdfTotalRow(table, "Tổng thu nhập (" + incCount + " GD)", formatMoneyVndPlain(totalInc),
                new Font(bf, 8, Font.BOLD, incomeGreen), headerFont, accentBlue, borderGray);
        addPdfTotalRow(table, "Chênh lệch (Thu − Chi)", formatMoneyVndPlain(balance),
                new Font(bf, 8, Font.BOLD, balance >= 0 ? incomeGreen : expenseRed), headerFont, accentBlue, borderGray);
    }

    private void addPdfTotalRow(
            PdfPTable table,
            String label,
            String amount,
            Font amountFont,
            Font headerFont,
            Color headerBg,
            Color borderGray) {

        PdfPCell labelCell = borderedCell(new Phrase(label, headerFont), headerBg, Element.ALIGN_RIGHT, borderGray);
        labelCell.setColspan(2);
        labelCell.setPadding(7);
        table.addCell(labelCell);

        PdfPCell amountCell = borderedCell(new Phrase(amount, amountFont), headerBg, Element.ALIGN_RIGHT, borderGray);
        amountCell.setPadding(7);
        table.addCell(amountCell);

        PdfPCell pad = borderedCell(new Phrase("", amountFont), headerBg, Element.ALIGN_LEFT, borderGray);
        pad.setColspan(3);
        pad.setPadding(7);
        table.addCell(pad);
    }

    private PdfPCell borderedCell(Phrase phrase, Color bg, int align, Color borderColor) {
        PdfPCell c = new PdfPCell(phrase);
        c.setBackgroundColor(bg);
        c.setHorizontalAlignment(align);
        c.setVerticalAlignment(Element.ALIGN_MIDDLE);
        c.setBorderWidth(0.5f);
        c.setBorderColor(borderColor);
        return c;
    }

    private void addPdfHeaderBar(Document document, Color accentBlue) throws DocumentException {
        PdfPTable headerBar = new PdfPTable(1);
        headerBar.setWidthPercentage(100);
        PdfPCell barCell = new PdfPCell(new Phrase(" "));
        barCell.setBackgroundColor(accentBlue);
        barCell.setBorder(Rectangle.NO_BORDER);
        barCell.setFixedHeight(5);
        headerBar.addCell(barCell);
        document.add(headerBar);
        document.add(new Paragraph(" "));
    }

    private Paragraph centeredParagraph(String text, Font font) {
        return centeredParagraph(text, font, 4);
    }

    private Paragraph centeredParagraph(String text, Font font, float spacingAfter) {
        Paragraph p = new Paragraph(text, font);
        p.setAlignment(Element.ALIGN_CENTER);
        p.setSpacingAfter(spacingAfter);
        return p;
    }

    private BaseFont loadBaseFont() throws IOException, DocumentException {
        try (InputStream is = getClass().getResourceAsStream(FONT_PATH)) {
            if (is == null) {
                log.error("Missing font at {}", FONT_PATH);
                throw new IllegalStateException("Font NotoSans-Regular.ttf not found in resources");
            }
            byte[] fontBytes = is.readAllBytes();
            return BaseFont.createFont("NotoSans-Regular.ttf", BaseFont.IDENTITY_H, BaseFont.EMBEDDED, true, fontBytes, null);
        }
    }

    private Map<String, CategoryAgg> aggregateByCategory(List<Transaction> transactions, TransactionType type) {
        Map<String, CategoryAgg> map = new LinkedHashMap<>();
        for (Transaction t : transactions) {
            if (t.getType() != type) continue;
            String name = t.getCategory().getName();
            CategoryAgg agg = map.computeIfAbsent(name, k -> new CategoryAgg());
            agg.count++;
            agg.total += t.getAmount().doubleValue();
        }
        return map;
    }

    private void addKpiCell(PdfPTable table, String label, String value, Color borderColor, Color valueColor,
                            BaseFont bf, Color bg) {
        Font fontLabel = new Font(bf, 9, Font.NORMAL, new Color(0x64, 0x74, 0x8B));
        Font fontValue = new Font(bf, 13, Font.BOLD, valueColor);

        PdfPCell cell = new PdfPCell();
        cell.setBorder(Rectangle.BOX);
        cell.setBorderWidth(1.2f);
        cell.setBorderColor(borderColor);
        cell.setPadding(14);
        cell.setBackgroundColor(bg);
        cell.setMinimumHeight(58);

        Paragraph pl = new Paragraph(label, fontLabel);
        pl.setSpacingAfter(4);
        cell.addElement(pl);
        cell.addElement(new Paragraph(value, fontValue));
        table.addCell(cell);
    }

    private void addTableCell(PdfPTable table, String text, Font font, int align, Color bg, Color borderGray) {
        PdfPCell c = borderedCell(new Phrase(text, font), bg, align, borderGray);
        c.setPadding(6);
        table.addCell(c);
    }

    private String formatMoneyVnd(double v) {
        DecimalFormatSymbols sym = new DecimalFormatSymbols(Locale.forLanguageTag("vi-VN"));
        sym.setGroupingSeparator('.');
        DecimalFormat df = new DecimalFormat("#,##0", sym);
        return df.format(Math.round(v)) + " ₫";
    }

    private String formatMoneyVndPlain(double v) {
        DecimalFormatSymbols sym = new DecimalFormatSymbols(Locale.forLanguageTag("vi-VN"));
        sym.setGroupingSeparator('.');
        DecimalFormat df = new DecimalFormat("#,##0", sym);
        return df.format(Math.round(v));
    }

    private double sumExpense(List<Transaction> list) {
        return list.stream()
                .filter(t -> t.getType() == TransactionType.EXPENSE)
                .mapToDouble(t -> t.getAmount().doubleValue())
                .sum();
    }

    private double sumIncome(List<Transaction> list) {
        return list.stream()
                .filter(t -> t.getType() == TransactionType.INCOME)
                .mapToDouble(t -> t.getAmount().doubleValue())
                .sum();
    }

    private String walletName(Transaction t) {
        return t.getWallet() != null ? t.getWallet().getName() : "—";
    }

    private String blankToDash(String s) {
        return s != null && !s.isBlank() ? s : "—";
    }

    private String safe(String s) {
        return s != null && !s.isBlank() ? s : "—";
    }

    private static final class CategoryAgg {
        int count;
        double total;
    }

    private static final class ExcelStyles {
        final XSSFCellStyle brandBanner;
        final XSSFCellStyle titleReport;
        final XSSFCellStyle subtitle;
        final XSSFCellStyle footer;
        final XSSFCellStyle sectionTitle;
        final XSSFCellStyle tableHeader;
        final XSSFCellStyle rowBase;
        final XSSFCellStyle rowAlt;
        final XSSFCellStyle rowBaseWrap;
        final XSSFCellStyle rowAltWrap;
        final XSSFCellStyle typeExpense;
        final XSSFCellStyle typeIncome;
        final XSSFCellStyle moneyExpense;
        final XSSFCellStyle moneyIncome;
        final XSSFCellStyle moneyNeutral;
        final XSSFCellStyle percent;
        final XSSFCellStyle kpiExpense;
        final XSSFCellStyle kpiIncome;
        final XSSFCellStyle kpiPositive;
        final XSSFCellStyle kpiNegative;
        final XSSFCellStyle kpiPositiveAmount;
        final XSSFCellStyle kpiNegativeAmount;

        ExcelStyles(XSSFWorkbook wb) {
            DataFormat df = wb.createDataFormat();

            brandBanner = base(wb, 11, true, IndexedColors.WHITE.getIndex(), rgb(RGB_PRIMARY), HorizontalAlignment.CENTER);
            titleReport = base(wb, 14, true, rgb(RGB_TEXT), null, HorizontalAlignment.LEFT);
            subtitle = base(wb, 10, false, rgb(RGB_MUTED), null, HorizontalAlignment.LEFT);
            footer = base(wb, 9, false, rgb(RGB_MUTED), null, HorizontalAlignment.LEFT);

            sectionTitle = base(wb, 12, true, rgb(RGB_PRIMARY), rgb(RGB_PRIMARY_LIGHT), HorizontalAlignment.LEFT);
            sectionTitle.setIndention((short) 0);

            tableHeader = base(wb, 10, true, IndexedColors.WHITE.getIndex(), rgb(RGB_PRIMARY), HorizontalAlignment.CENTER);
            bordered(tableHeader);

            rowBase = base(wb, 10, false, rgb(RGB_TEXT), null, HorizontalAlignment.LEFT);
            bordered(rowBase);

            rowAlt = base(wb, 10, false, rgb(RGB_TEXT), rgb(RGB_ROW_ALT), HorizontalAlignment.LEFT);
            bordered(rowAlt);

            rowBaseWrap = wrapCopy(wb, rowBase);
            rowAltWrap = wrapCopy(wb, rowAlt);

            typeExpense = base(wb, 10, true, rgb(new byte[]{(byte) 0xB9, (byte) 0x1C, (byte) 0x1C}), rgb(RGB_EXPENSE), HorizontalAlignment.CENTER);
            bordered(typeExpense);

            typeIncome = base(wb, 10, true, rgb(new byte[]{(byte) 0x15, (byte) 0x80, (byte) 0x3D}), rgb(RGB_INCOME), HorizontalAlignment.CENTER);
            bordered(typeIncome);

            moneyExpense = base(wb, 10, true, rgb(new byte[]{(byte) 0xB9, (byte) 0x1C, (byte) 0x1C}), rgb(RGB_EXPENSE), HorizontalAlignment.RIGHT);
            moneyExpense.setDataFormat(df.getFormat("#,##0"));
            bordered(moneyExpense);

            moneyIncome = base(wb, 10, true, rgb(new byte[]{(byte) 0x15, (byte) 0x80, (byte) 0x3D}), rgb(RGB_INCOME), HorizontalAlignment.RIGHT);
            moneyIncome.setDataFormat(df.getFormat("#,##0"));
            bordered(moneyIncome);

            moneyNeutral = base(wb, 10, true, rgb(RGB_TEXT), null, HorizontalAlignment.RIGHT);
            moneyNeutral.setDataFormat(df.getFormat("#,##0"));
            bordered(moneyNeutral);

            percent = base(wb, 10, false, rgb(RGB_TEXT), null, HorizontalAlignment.CENTER);
            percent.setDataFormat(df.getFormat("0.0"));
            bordered(percent);

            kpiExpense = kpiBox(wb, rgb(RGB_EXPENSE), rgb(new byte[]{(byte) 0xB9, (byte) 0x1C, (byte) 0x1C}));
            kpiIncome = kpiBox(wb, rgb(RGB_INCOME), rgb(new byte[]{(byte) 0x15, (byte) 0x80, (byte) 0x3D}));
            kpiPositive = kpiBox(wb, rgb(RGB_PRIMARY_LIGHT), rgb(RGB_PRIMARY));
            kpiNegative = kpiBox(wb, rgb(RGB_EXPENSE), rgb(new byte[]{(byte) 0xB9, (byte) 0x1C, (byte) 0x1C}));

            kpiPositiveAmount = base(wb, 10, true, rgb(RGB_PRIMARY), rgb(RGB_PRIMARY_LIGHT), HorizontalAlignment.RIGHT);
            kpiPositiveAmount.setDataFormat(df.getFormat("#,##0"));
            bordered(kpiPositiveAmount);

            kpiNegativeAmount = base(wb, 10, true, rgb(new byte[]{(byte) 0xB9, (byte) 0x1C, (byte) 0x1C}), rgb(RGB_EXPENSE), HorizontalAlignment.RIGHT);
            kpiNegativeAmount.setDataFormat(df.getFormat("#,##0"));
            bordered(kpiNegativeAmount);
        }

        private XSSFCellStyle wrapCopy(XSSFWorkbook wb, XSSFCellStyle source) {
            XSSFCellStyle wrap = wb.createCellStyle();
            wrap.cloneStyleFrom(source);
            wrap.setWrapText(true);
            wrap.setVerticalAlignment(VerticalAlignment.TOP);
            return wrap;
        }

        private XSSFCellStyle kpiBox(XSSFWorkbook wb, XSSFColor bg, XSSFColor border) {
            XSSFCellStyle style = base(wb, 11, true, rgb(RGB_TEXT), bg, HorizontalAlignment.CENTER);
            style.setVerticalAlignment(VerticalAlignment.CENTER);
            style.setWrapText(true);
            style.setBorderTop(BorderStyle.MEDIUM);
            style.setBorderBottom(BorderStyle.MEDIUM);
            style.setBorderLeft(BorderStyle.MEDIUM);
            style.setBorderRight(BorderStyle.MEDIUM);
            style.setTopBorderColor(border);
            style.setBottomBorderColor(border);
            style.setLeftBorderColor(border);
            style.setRightBorderColor(border);
            return style;
        }

        private XSSFCellStyle base(
                XSSFWorkbook wb,
                int fontSize,
                boolean bold,
                Object fontColor,
                XSSFColor fill,
                HorizontalAlignment align) {

            XSSFCellStyle style = wb.createCellStyle();
            XSSFFont font = wb.createFont();
            font.setFontName("Calibri");
            font.setFontHeightInPoints((short) fontSize);
            font.setBold(bold);
            if (fontColor instanceof XSSFColor c) {
                font.setColor(c);
            } else if (fontColor instanceof Short idx) {
                font.setColor(idx);
            }
            style.setFont(font);
            style.setAlignment(align);
            style.setVerticalAlignment(VerticalAlignment.CENTER);
            if (fill != null) {
                style.setFillForegroundColor(fill);
                style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            }
            return style;
        }

        private void bordered(XSSFCellStyle style) {
            style.setBorderTop(BorderStyle.THIN);
            style.setBorderBottom(BorderStyle.THIN);
            style.setBorderLeft(BorderStyle.THIN);
            style.setBorderRight(BorderStyle.THIN);
            XSSFColor border = rgb(new byte[]{(byte) 0xE2, (byte) 0xE8, (byte) 0xF0});
            style.setTopBorderColor(border);
            style.setBottomBorderColor(border);
            style.setLeftBorderColor(border);
            style.setRightBorderColor(border);
        }

        private XSSFColor rgb(byte[] rgb) {
            return new XSSFColor(rgb, null);
        }
    }

    private static final class PdfFooterEvent extends PdfPageEventHelper {
        private final BaseFont bf;
        private final Font footerFont;
        private final Color accent;

        PdfFooterEvent(BaseFont bf, Font footerFont, Color accent) {
            this.bf = bf;
            this.footerFont = footerFont;
            this.accent = accent;
        }

        @Override
        public void onEndPage(PdfWriter writer, Document document) {
            PdfPTable footer = new PdfPTable(2);
            try {
                footer.setWidths(new float[]{3f, 1f});
                footer.setTotalWidth(document.right() - document.left());
                footer.setLockedWidth(true);

                PdfPCell left = new PdfPCell(new Phrase(
                        "Expense Manager • Báo cáo tự động • " + LocalDate.now().format(DATE_FORMAT), footerFont));
                left.setBorder(Rectangle.TOP);
                left.setBorderColor(accent);
                left.setPaddingTop(8);
                left.setHorizontalAlignment(Element.ALIGN_LEFT);

                PdfPCell right = new PdfPCell(new Phrase(
                        "Trang " + writer.getPageNumber(), footerFont));
                right.setBorder(Rectangle.TOP);
                right.setBorderColor(accent);
                right.setPaddingTop(8);
                right.setHorizontalAlignment(Element.ALIGN_RIGHT);

                footer.addCell(left);
                footer.addCell(right);
                footer.writeSelectedRows(0, -1, document.left(), document.bottom() - 8, writer.getDirectContent());
            } catch (DocumentException e) {
                log.warn("PDF footer render failed", e);
            }
        }
    }
}
