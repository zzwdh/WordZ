export function buildPaginationDisplayState({
  totalRows = 0,
  currentPage = 1,
  totalPages = 0,
  showAll = false,
  zeroPageLabel = '第 0 / 0 页',
  allPageLabel = '全部显示'
} = {}) {
  const safeTotalRows = Math.max(0, Number(totalRows) || 0)
  const safeCurrentPage = Math.max(1, Number(currentPage) || 1)
  const safeTotalPages = Math.max(0, Number(totalPages) || 0)

  if (safeTotalRows === 0 || safeTotalPages === 0) {
    return {
      pageLabel: zeroPageLabel,
      previousDisabled: true,
      nextDisabled: true,
      hasRows: false
    }
  }

  if (showAll) {
    return {
      pageLabel: allPageLabel,
      previousDisabled: true,
      nextDisabled: true,
      hasRows: true
    }
  }

  return {
    pageLabel: `第 ${safeCurrentPage} / ${safeTotalPages} 页`,
    previousDisabled: safeCurrentPage === 1,
    nextDisabled: safeCurrentPage === safeTotalPages,
    hasRows: true
  }
}
