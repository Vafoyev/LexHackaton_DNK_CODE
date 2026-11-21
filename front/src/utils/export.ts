import { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, BorderStyle } from 'docx';
import saveAs from 'file-saver';
import { jsPDF } from 'jspdf';
import { AnalysisResult } from '../types/contract';

/**
 * Kelishuv 3.2 bo'yicha:
 * 1) Takliflar .docx — har band yonida izoh (nima, nega, modda, tavsiya) + kelishmovchiliklar bayonnomasi
 * 2) Audit bayonnomasi PDF
 */

export async function exportToDocx(analysis: AnalysisResult) {
  const doc = new Document({
    sections: [
      {
        properties: {},
        children: [
          new Paragraph({
            text: "LEXGUARD AI — YURIDIK TAHLIL VA REDLINE TAKLIFLAR BAYONNOMASI",
            heading: HeadingLevel.TITLE,
            spacing: { after: 200 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: "Hujjat nomi: ", bold: true }),
              new TextRun({ text: `${analysis.document.filename}\n` }),
              new TextRun({ text: "Sana: ", bold: true }),
              new TextRun({ text: `${analysis.document.contract_date} (SHA256: ${analysis.document.sha256.substring(0, 16)}...)\n` }),
              new TextRun({ text: "Xavf Indeksi: ", bold: true }),
              new TextRun({ text: `${analysis.summary.risk_score}/100 | Qizil: ${analysis.summary.red_count}, Sariq: ${analysis.summary.yellow_count}, Yashil: ${analysis.summary.green_count}\n` }),
              new TextRun({ text: "Taraflar Balansi: ", bold: true }),
              new TextRun({ text: `${analysis.summary.balance_label}\n\n` }),
            ],
            spacing: { after: 300 },
          }),

          new Paragraph({
            text: "1. KELISHMOVCHILIKLAR BAYONNOMASI (PROTOKOL RAZNOGLASIY)",
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 200, after: 200 },
          }),

          // Table of findings
          new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            rows: [
              new TableRow({
                children: [
                  new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Band", bold: true })] })], width: { size: 10, type: WidthType.PERCENTAGE } }),
                  new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Xavf Turi", bold: true })] })], width: { size: 15, type: WidthType.PERCENTAGE } }),
                  new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Asl Matn", bold: true })] })], width: { size: 25, type: WidthType.PERCENTAGE } }),
                  new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Tavsiya Qilingan Tahrir (Redline)", bold: true })] })], width: { size: 30, type: WidthType.PERCENTAGE } }),
                  new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Qonuniy Asos (Lex.uz)", bold: true })] })], width: { size: 20, type: WidthType.PERCENTAGE } }),
                ],
              }),
              ...analysis.findings.map(f => (
                new TableRow({
                  children: [
                    new TableCell({ children: [new Paragraph(f.clause_number)] }),
                    new TableCell({ 
                      children: [
                        new Paragraph({ 
                          children: [
                            new TextRun({ 
                              text: `${f.risk_level === 'RED' ? '🔴 QIZIL (Huquqiy)' : f.risk_level === 'YELLOW' ? '🟡 SARIQ (Tijoriy)' : '⚪ KULRANG'}`,
                              bold: true 
                            })
                          ]
                        })
                      ] 
                    }),
                    new TableCell({ children: [new Paragraph(f.original_quote)] }),
                    new TableCell({ 
                      children: [
                        new Paragraph({ children: [new TextRun({ text: f.suggested_redline, bold: true })] }),
                        new Paragraph({ text: `Asos: ${f.redline_reasoning}` })
                      ] 
                    }),
                    new TableCell({ 
                      children: [
                        new Paragraph({ children: [new TextRun({ text: `${f.legal_basis.article}`, bold: true })] }),
                        new Paragraph({ text: `Havola: ${f.legal_basis.lex_uz_url}` })
                      ] 
                    }),
                  ]
                })
              ))
            ]
          }),

          new Paragraph({
            text: "\n2. YURIDIK OGOHLANTIRISH",
            heading: HeadingLevel.HEADING_2,
            spacing: { before: 400, after: 150 },
          }),
          new Paragraph({
            children: [
              new TextRun({
                text: analysis.disclaimer,
                italics: true,
              })
            ]
          })
        ],
      },
    ],
  });

  const blob = await Packer.toBlob(doc);
  saveAs(blob, `LexGuard_Redline_${analysis.document.filename.replace(/\.[^/.]+$/, "")}.docx`);
}

export function exportToPDF(analysis: AnalysisResult) {
  const pdf = new jsPDF();
  let y = 20;

  pdf.setFontSize(16);
  pdf.setTextColor(14, 116, 144);
  pdf.text("LEXGUARD AI — HUQUQIY AUDIT HISOBOTI", 14, y);
  
  y += 10;
  pdf.setFontSize(10);
  pdf.setTextColor(60, 60, 60);
  pdf.text(`Hujjat: ${analysis.document.filename}`, 14, y);
  y += 6;
  pdf.text(`Sana: ${analysis.document.contract_date} | Xavf Indeksi: ${analysis.summary.risk_score}/100`, 14, y);
  y += 6;
  pdf.text(`Balans holati: ${analysis.summary.balance_label}`, 14, y);
  y += 6;
  pdf.text(`Topilmalar: ${analysis.summary.red_count} ta Qizil (Huquqiy), ${analysis.summary.yellow_count} ta Sariq (Tijoriy), ${analysis.summary.green_count} ta Yashil`, 14, y);

  y += 12;
  pdf.setFontSize(12);
  pdf.setTextColor(20, 20, 20);
  pdf.text("Aniqlangan Xavflar va Qonuniy Asoslar:", 14, y);
  y += 8;

  analysis.findings.forEach((finding, index) => {
    if (y > 260) {
      pdf.addPage();
      y = 20;
    }
    
    pdf.setFontSize(10);
    const color = finding.risk_level === 'RED' ? [220, 38, 38] : finding.risk_level === 'YELLOW' ? [217, 119, 6] : [75, 85, 99];
    pdf.setTextColor(color[0], color[1], color[2]);
    pdf.text(`${index + 1}. [${finding.risk_level}] ${finding.clause_number}-band: ${finding.issue_title}`, 14, y);
    y += 5;

    pdf.setFontSize(9);
    pdf.setTextColor(80, 80, 80);
    const splitOrig = pdf.splitTextToSize(`Asl matn: "${finding.original_quote}"`, 180);
    pdf.text(splitOrig, 14, y);
    y += splitOrig.length * 4.5;

    pdf.setTextColor(15, 118, 110);
    const splitRedline = pdf.splitTextToSize(`Tavsiya (Redline): "${finding.suggested_redline}"`, 180);
    pdf.text(splitRedline, 14, y);
    y += splitRedline.length * 4.5;

    pdf.setTextColor(100, 100, 100);
    pdf.text(`Asos: ${finding.legal_basis.source_title}, ${finding.legal_basis.article}`, 14, y);
    y += 8;
  });

  if (y > 250) {
    pdf.addPage();
    y = 20;
  }
  y += 10;
  pdf.setFontSize(8);
  pdf.setTextColor(120, 120, 120);
  const splitDisclaimer = pdf.splitTextToSize(analysis.disclaimer, 180);
  pdf.text(splitDisclaimer, 14, y);

  pdf.save(`LexGuard_Audit_${analysis.document.filename.replace(/\.[^/.]+$/, "")}.pdf`);
}
