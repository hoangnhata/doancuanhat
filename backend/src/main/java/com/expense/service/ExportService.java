package com.expense.service;

import com.expense.entity.Transaction;
import com.expense.entity.User;
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
import com.lowagie.text.pdf.PdfWriter;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
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
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class ExportService {

    private static final Logger log = LoggerFactory.getLogger(ExportService.class);
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final String FONT_PATH = "/fonts/NotoSans-Regular.ttf";

    private final TransactionRepository transactionRepository;
    private final UserService userService;

    @Transactional(readOnly = true)
    public byte[] exportExcel(LocalDate startDate, LocalDate endDate) throws IOException {
        User user = userService.getCurrentUserEntity();
        List<Transaction> transactions = transactionRepository.findByUserIdAndTransactionDateBetweenAll(
                user.getId(), startDate, endDate);

        try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sheet = workbook.createSheet("Giao dịch");

            CellStyle headerStyle = workbook.createCellStyle();
            org.apache.poi.ss.usermodel.Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerStyle.setFont(headerFont);

            int rowNum = 0;

            Row headerRow = sheet.createRow(rowNum++);
            String[] headers = {"Ngày", "Loại", "Số tiền", "Danh mục", "Mô tả"};
            for (int i = 0; i < headers.length; i++) {
                Cell cell = headerRow.createCell(i);
                cell.setCellValue(headers[i]);
                cell.setCellStyle(headerStyle);
            }

            for (Transaction t : transactions) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(t.getTransactionDate().format(DATE_FORMAT));
                row.createCell(1).setCellValue(t.getType().name().equals("EXPENSE") ? "Chi phí" : "Thu nhập");
                row.createCell(2).setCellValue(t.getAmount().doubleValue());
                row.createCell(3).setCellValue(t.getCategory().getName());
                row.createCell(4).setCellValue(t.getDescription() != null ? t.getDescription() : "");
            }

            rowNum++;
            Row sumRow = sheet.createRow(rowNum++);
            sumRow.createCell(0).setCellValue("Tổng chi phí");
            sumRow.createCell(1).setCellValue(sumExpense(transactions));

            Row incomeRow = sheet.createRow(rowNum++);
            incomeRow.createCell(0).setCellValue("Tổng thu nhập");
            incomeRow.createCell(1).setCellValue(sumIncome(transactions));

            Row diffRow = sheet.createRow(rowNum);
            diffRow.createCell(0).setCellValue("Chênh lệch");
            diffRow.createCell(1).setCellValue(sumIncome(transactions) - sumExpense(transactions));

            for (int i = 0; i < 5; i++) {
                sheet.autoSizeColumn(i);
            }

            workbook.write(out);
            return out.toByteArray();
        }
    }

    /**
     * Báo cáo PDF: header, tóm tắt KPI, bảng chi tiết, chân trang — font Noto Sans (tiếng Việt).
     */
    @Transactional(readOnly = true)
    public byte[] exportPdf(LocalDate startDate, LocalDate endDate) throws IOException, DocumentException {
        User user = userService.getCurrentUserEntity();
        List<Transaction> transactions = transactionRepository.findByUserIdAndTransactionDateBetweenAll(
                user.getId(), startDate, endDate);

        byte[] fontBytes;
        try (InputStream is = getClass().getResourceAsStream(FONT_PATH)) {
            if (is == null) {
                log.error("Missing font at {}", FONT_PATH);
                throw new IllegalStateException("Font NotoSans-Regular.ttf not found in resources");
            }
            fontBytes = is.readAllBytes();
        }

        BaseFont bf = BaseFont.createFont("NotoSans-Regular.ttf", BaseFont.IDENTITY_H, BaseFont.EMBEDDED, true, fontBytes, null);

        Color accentBlue = new Color(0x02, 0x88, 0xD1);
        Color textDark = new Color(0x1A, 0x23, 0x7E);
        Color textMuted = new Color(0x37, 0x47, 0x4F);
        Color expenseRed = new Color(0xD3, 0x2F, 0x2F);
        Color incomeGreen = new Color(0x4C, 0xAF, 0x50);
        Color rowAlt = new Color(0xF5, 0xFA, 0xFF);
        Color headerWhite = Color.WHITE;

        Font titleFont = new Font(bf, 20, Font.BOLD, accentBlue);
        Font subtitleFont = new Font(bf, 10, Font.NORMAL, textMuted);
        Font headerFont = new Font(bf, 9, Font.BOLD, headerWhite);
        Font cellFont = new Font(bf, 8, Font.NORMAL, textDark);
        Font footerFont = new Font(bf, 8, Font.ITALIC, textMuted);

        double totalExp = sumExpense(transactions);
        double totalInc = sumIncome(transactions);
        double balance = totalInc - totalExp;

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Document document = new Document(PageSize.A4, 40, 40, 48, 48);
        PdfWriter.getInstance(document, baos);
        document.open();

        // --- Thanh tiêu đề nổi bật ---
        PdfPTable headerBar = new PdfPTable(1);
        headerBar.setWidthPercentage(100);
        PdfPCell barCell = new PdfPCell(new Phrase(" ", new Font(bf, 4, Font.NORMAL)));
        barCell.setBackgroundColor(accentBlue);
        barCell.setBorder(Rectangle.NO_BORDER);
        barCell.setFixedHeight(6);
        headerBar.addCell(barCell);
        document.add(headerBar);

        document.add(new Paragraph(" "));

        Paragraph title = new Paragraph("Báo cáo giao dịch", titleFont);
        title.setAlignment(Element.ALIGN_CENTER);
        title.setSpacingAfter(6);
        document.add(title);

        String period = "Kỳ: " + startDate.format(DATE_FORMAT) + "  —  " + endDate.format(DATE_FORMAT);
        Paragraph pPeriod = new Paragraph(period, subtitleFont);
        pPeriod.setAlignment(Element.ALIGN_CENTER);
        document.add(pPeriod);

        String userLine = (user.getFullName() != null ? user.getFullName() : "") + "  •  " + user.getEmail();
        Paragraph pUser = new Paragraph(userLine, subtitleFont);
        pUser.setAlignment(Element.ALIGN_CENTER);
        pUser.setSpacingAfter(4);
        document.add(pUser);

        Paragraph pCount = new Paragraph("Số giao dịch: " + transactions.size(), subtitleFont);
        pCount.setAlignment(Element.ALIGN_CENTER);
        pCount.setSpacingAfter(16);
        document.add(pCount);

        // --- 3 ô tóm tắt ---
        PdfPTable kpi = new PdfPTable(3);
        kpi.setWidthPercentage(100);
        kpi.setWidths(new float[]{1f, 1f, 1f});
        kpi.setSpacingAfter(18);

        addKpiCell(kpi, "Tổng chi phí", formatMoneyVnd(totalExp), expenseRed, expenseRed, bf, rowAlt);
        addKpiCell(kpi, "Tổng thu nhập", formatMoneyVnd(totalInc), incomeGreen, incomeGreen, bf, rowAlt);
        addKpiCell(kpi, "Chênh lệch", formatMoneyVnd(balance), accentBlue, balance >= 0 ? incomeGreen : expenseRed, bf, rowAlt);
        document.add(kpi);

        // --- Bảng chi tiết ---
        Paragraph tableTitle = new Paragraph("Chi tiết giao dịch", new Font(bf, 12, Font.BOLD, textDark));
        tableTitle.setSpacingAfter(8);
        document.add(tableTitle);

        PdfPTable table = new PdfPTable(5);
        table.setWidthPercentage(100);
        table.setWidths(new float[]{1.2f, 1f, 1.3f, 1.4f, 2.1f});
        table.setHeaderRows(1);
        table.setSplitLate(false);
        table.setSplitRows(true);

        String[] headers = {"Ngày", "Loại", "Số tiền (₫)", "Danh mục", "Mô tả"};
        for (String h : headers) {
            PdfPCell hc = new PdfPCell(new Phrase(h, headerFont));
            hc.setBackgroundColor(accentBlue);
            hc.setPadding(8);
            hc.setHorizontalAlignment(Element.ALIGN_CENTER);
            hc.setVerticalAlignment(Element.ALIGN_MIDDLE);
            table.addCell(hc);
        }

        int row = 0;
        for (Transaction t : transactions) {
            Color bg = row % 2 == 0 ? Color.WHITE : rowAlt;
            String type = t.getType().name().equals("EXPENSE") ? "Chi phí" : "Thu nhập";
            String desc = t.getDescription() != null && !t.getDescription().isBlank() ? t.getDescription() : "—";

            addTableCell(table, t.getTransactionDate().format(DATE_FORMAT), cellFont, Element.ALIGN_CENTER, bg);
            addTableCell(table, type, cellFont, Element.ALIGN_CENTER, bg);
            addTableCell(table, formatMoneyVndPlain(t.getAmount().doubleValue()), cellFont, Element.ALIGN_RIGHT, bg);
            addTableCell(table, t.getCategory().getName(), cellFont, Element.ALIGN_LEFT, bg);
            addTableCell(table, desc, cellFont, Element.ALIGN_LEFT, bg);
            row++;
        }

        if (transactions.isEmpty()) {
            PdfPCell empty = new PdfPCell(new Phrase("Không có giao dịch trong kỳ này.", new Font(bf, 9, Font.ITALIC, textMuted)));
            empty.setColspan(5);
            empty.setPadding(16);
            empty.setHorizontalAlignment(Element.ALIGN_CENTER);
            empty.setBackgroundColor(rowAlt);
            table.addCell(empty);
        }

        document.add(table);

        document.add(new Paragraph(" "));

        Paragraph footer = new Paragraph(
                "Báo cáo được tạo tự động từ Expense Manager • " + LocalDate.now().format(DATE_FORMAT), footerFont);
        footer.setAlignment(Element.ALIGN_CENTER);
        document.add(footer);

        document.close();
        return baos.toByteArray();
    }

    private void addKpiCell(PdfPTable table, String label, String value, Color borderColor, Color valueColor,
                            BaseFont bf, Color bg) {
        Font fontLabel = new Font(bf, 9, Font.NORMAL, new Color(0x78, 0x90, 0x9C));
        Font fontValue = new Font(bf, 13, Font.BOLD, valueColor);

        PdfPCell cell = new PdfPCell();
        cell.setBorder(Rectangle.BOX);
        cell.setBorderWidth(1.2f);
        cell.setBorderColor(borderColor);
        cell.setPadding(14);
        cell.setBackgroundColor(bg);
        cell.setMinimumHeight(56);

        Paragraph pl = new Paragraph(label, fontLabel);
        pl.setSpacingAfter(4);
        cell.addElement(pl);
        cell.addElement(new Paragraph(value, fontValue));

        table.addCell(cell);
    }

    private void addTableCell(PdfPTable table, String text, Font font, int align, Color bg) {
        PdfPCell c = new PdfPCell(new Phrase(text, font));
        c.setPadding(6);
        c.setHorizontalAlignment(align);
        c.setVerticalAlignment(Element.ALIGN_MIDDLE);
        c.setBackgroundColor(bg);
        table.addCell(c);
    }

    private String formatMoneyVnd(double v) {
        DecimalFormatSymbols sym = new DecimalFormatSymbols(Locale.forLanguageTag("vi-VN"));
        sym.setGroupingSeparator('.');
        DecimalFormat df = new DecimalFormat("#,##0", sym);
        return df.format(Math.round(v)) + " ₫";
    }

    /** Không có ký tự nhóm để cột hẹp vừa */
    private String formatMoneyVndPlain(double v) {
        DecimalFormatSymbols sym = new DecimalFormatSymbols(Locale.forLanguageTag("vi-VN"));
        sym.setGroupingSeparator('.');
        DecimalFormat df = new DecimalFormat("#,##0", sym);
        return df.format(Math.round(v));
    }

    private double sumExpense(List<Transaction> list) {
        return list.stream()
                .filter(t -> t.getType().name().equals("EXPENSE"))
                .mapToDouble(t -> t.getAmount().doubleValue())
                .sum();
    }

    private double sumIncome(List<Transaction> list) {
        return list.stream()
                .filter(t -> t.getType().name().equals("INCOME"))
                .mapToDouble(t -> t.getAmount().doubleValue())
                .sum();
    }
}
