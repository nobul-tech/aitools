"""Generate a small test PDF (heading, paragraph, table, formula) for MinerU smoke test."""
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet

out = "/Users/new-jose/repos/aitools/.scratch/session-06c9c816-5/test.pdf"
styles = getSampleStyleSheet()
doc = SimpleDocTemplate(out, pagesize=letter)
story = [
    Paragraph("Quarterly Revenue Report", styles["Title"]),
    Paragraph(
        "This document tests PDF to markdown conversion fidelity across a "
        "heading, a paragraph, a data table, and an inline formula such as "
        "E = mc^2 and the quadratic root x = (-b +/- sqrt(b^2 - 4ac)) / 2a.",
        styles["BodyText"],
    ),
    Spacer(1, 12),
]
data = [
    ["Quarter", "Revenue ($M)", "Growth (%)"],
    ["Q1 2026", "12.4", "8.1"],
    ["Q2 2026", "15.9", "28.2"],
    ["Q3 2026", "18.3", "15.1"],
]
t = Table(data)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#333333")),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
    ("ALIGN", (1, 0), (-1, -1), "CENTER"),
]))
story.append(t)
doc.build(story)
print("wrote", out)
