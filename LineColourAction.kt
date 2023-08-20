package com.example.line_level_risk

import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.editor.Editor
import com.intellij.openapi.editor.markup.HighlighterLayer
import com.intellij.openapi.editor.markup.HighlighterTargetArea
import com.intellij.openapi.editor.markup.MarkupModel
import com.intellij.openapi.editor.markup.TextAttributes
import com.intellij.openapi.fileChooser.FileChooser
import com.intellij.openapi.fileChooser.FileChooserDescriptor
import com.intellij.openapi.project.Project
import com.intellij.psi.PsiDocumentManager
import com.intellij.psi.PsiFile
import com.intellij.psi.util.PsiUtilBase
import java.awt.Color
import java.io.BufferedReader
import java.io.FileReader
import java.io.IOException
import java.util.*

class LineColourAction : AnAction() {
    override fun actionPerformed(e: AnActionEvent) {
        var combinedData: HashMap<Int, Double> = HashMap<Int, Double>()

        val project: Project? = e.project
        val editor: Editor? = e.getData(com.intellij.openapi.actionSystem.CommonDataKeys.EDITOR)

        if (project == null || editor == null) return

        val psiFile: PsiFile? = PsiUtilBase.getPsiFileInEditor(editor, project)

        val virtualFile = psiFile?.virtualFile

        val fileOpenInEditorPath = virtualFile?.path

        val fileChooserDescriptor = FileChooserDescriptor(
            true,
            false,
            false,
            false,
            false,
            false
        )

        fileChooserDescriptor.title = "Select DeepLineDP prediction file (.csv)"

        FileChooser.chooseFile(fileChooserDescriptor, null, null) { selectedVirtualFile ->
            try {
                combinedData =
                    extractRowDataFromFile(selectedVirtualFile.path, fileOpenInEditorPath)
            } catch (e: IOException) {
                e.printStackTrace()
            }
        }

        val psiManager: PsiDocumentManager = PsiDocumentManager.getInstance(project)
        val document = psiFile?.let { psiManager.getDocument(it) } ?: return

        val startLine: Int = 0
        val endLine: Int = document.lineCount

        val markupModel: MarkupModel = editor.markupModel

        for (line in startLine until endLine) {
            if (combinedData[line + 1] == null) {
                continue
            }
            val backgroundColor: TextAttributes = TextAttributes().apply {
                backgroundColor =
                    getColorForRiskValue(combinedData[line + 1])
            }

            val lineStartOffset: Int = document.getLineStartOffset(line)
            val lineEndOffset: Int = document.getLineEndOffset(line)

            markupModel.addRangeHighlighter(
                lineStartOffset, lineEndOffset, HighlighterLayer.LAST, backgroundColor,
                HighlighterTargetArea.EXACT_RANGE
            )
        }
    }

    fun extractRowDataFromFile(selectedVirtualFile: String, fileOpenInEditorPath: String?): HashMap<Int, Double> {
        val combinedData = HashMap<Int, Double>()

        BufferedReader(FileReader(selectedVirtualFile)).use { br ->
            var line: String?

            val filePathIndex = 3
            val lineNumberIndex = 7
            val isCommentLine = 9
            val attentionScoreIndex = 12

            var fileFound = false

            while (br.readLine().also { line = it } != null) {
                val columns = line!!.split(",")

                if (columns.size < 12) {
                    continue
                }

                if (fileOpenInEditorPath != null) {
                    if (!fileOpenInEditorPath.contains(columns[filePathIndex])) {
                        if (fileFound) {
                            break
                        }
                        continue
                    }
                }
                fileFound = true

                val lineNumber = columns[lineNumberIndex].trim().toInt()

                if (columns[isCommentLine].equals("True")) {
                    continue
                }

                val attentionScore = columns[attentionScoreIndex].trim().toDouble()
                if (!combinedData.containsKey(lineNumber)) {
                    combinedData[lineNumber] = attentionScore
                }
            }
        }

        return combinedData
    }

    private fun getColorForRiskValue(riskValue: Double?): Color {
        // Non-linear, lower risk values skewed to higher risk intensity
        //val alpha = (-(5 / (riskValue!! + 0.02)) + 260).toInt().coerceAtMost(255).coerceAtLeast(0)

        // Linear
        val alpha = (riskValue!! * 255).toInt().coerceAtMost(255).coerceAtLeast(0)

        return Color(255, 0, 0, alpha)
    }
}