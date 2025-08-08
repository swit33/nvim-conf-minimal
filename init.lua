vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.wrap = false
vim.o.tabstop = 4
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.winborder = "rounded"
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = false
vim.o.incsearch = true
vim.o.signcolumn = "yes"
vim.o.swapfile = false
vim.o.autoread = true
vim.opt.clipboard:append("unnamedplus")

local path_package = vim.fn.stdpath("data") .. "/site/"
local mini_path = path_package .. "pack/deps/start/mini.nvim"
if not vim.uv.fs_stat(mini_path) then
	vim.cmd('echo "Installing `mini.nvim`" | redraw')
	local clone_cmd = {
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/echasnovski/mini.nvim",
		mini_path,
	}
	vim.fn.system(clone_cmd)
	vim.cmd("packadd mini.nvim | helptags ALL")
	vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

require("mini.deps").setup({ path = { package = path_package } })

local add = MiniDeps.add

add({ source = "folke/tokyonight.nvim" })
add({ source = "neovim/nvim-lspconfig" })
add({ source = "mason-org/mason.nvim" })
add({ source = "echasnovski/mini.pick" })
add({ source = "echasnovski/mini.files" })
add({ source = "echasnovski/mini.jump" })
add({ source = "echasnovski/mini.pairs" })

vim.cmd.colorscheme("tokyonight")

require("mini.pick").setup({})
require("mini.files").setup({ options = { use_as_default_explorer = true } })
require("mini.jump").setup({})
require("mini.pairs").setup({})
require("mason").setup({})
require("lspconfig").lua_ls.setup({ settings = { Lua = { diagnostics = { globals = { "vim" } } } } })

vim.lsp.enable({
	"lua_ls",
})

vim.g.mapleader = " "
vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete without yanking" })
vim.keymap.set("n", "]b", ":bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "[b", ":bprevious<CR>", { desc = "Previous buffer" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
vim.keymap.set("n", "<leader>F", vim.lsp.buf.format, { desc = "Format Buffer" })
vim.keymap.set("n", "<leader>ff", ":Pick files<CR>", { desc = "File picker" })
vim.keymap.set("n", "<leader>fg", ":Pick grep_live<CR>", { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", ":Pick buffers<CR>", { desc = "Pick buffers" })
vim.keymap.set("n", "<leader>fh", ":Pick help<CR>", { desc = "Find help" })
vim.keymap.set("n", "<leader>e", function()
	require("mini.files").open()
end, { desc = "File Explorer" })

vim.keymap.set("i", "<Tab>", function()
	return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true, noremap = true, silent = true })

vim.keymap.set("i", "<S-Tab>", function()
	return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true, noremap = true, silent = true })

vim.keymap.set("i", "<Enter>", function()
	return vim.fn.pumvisible() == 1 and "<C-y>" or "<Enter>"
end, { expr = true, noremap = true, silent = true })

local augroup = vim.api.nvim_create_augroup("UserConfig", {})
vim.api.nvim_create_autocmd("TextYankPost", {
	group = augroup,
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("TextChangedI", {
	group = augroup,
	callback = function()
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		if col > 1 and line:sub(col - 1, col):match("%w") then
			if vim.bo.omnifunc == "v:lua.vim.lsp.omnifunc" then
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n", false)
			end
		end
	end,
})

vim.o.wildmenu = true
vim.o.wildmode = "longest:full,full"
vim.opt.completeopt = { "menu", "menuone", "noselect", "noinsert" }
vim.diagnostic.config({ virtual_text = true })

local function get_filename()
	local fname = vim.api.nvim_buf_get_name(0)
	return fname == "" and "[No Name]" or vim.fn.fnamemodify(fname, ":t")
end

local function get_mode()
	local mode = vim.api.nvim_get_mode().mode
	local mode_map = {
		n = "NORMAL",
		i = "INSERT",
		v = "VISUAL",
		V = "V-LINE",
		[""] = "V-BLOCK", -- Ctrl-V in Lua string requires special handling
		c = "COMMAND",
		R = "REPLACE",
		s = "SELECT",
		S = "S-LINE",
		[""] = "S-BLOCK",
	}
	return mode_map[mode] or mode:upper()
end

local function get_lsp()
	local counts = { errors = 0, warnings = 0 }
	local diagnostics = vim.diagnostic.get(0) -- 0 for current buffer
	for _, diag in ipairs(diagnostics) do
		if diag.severity == vim.diagnostic.severity.ERROR then
			counts.errors = counts.errors + 1
		elseif diag.severity == vim.diagnostic.severity.WARN then
			counts.warnings = counts.warnings + 1
		end
	end
	local result = ""
	if counts.errors > 0 then
		result = result .. "E:" .. counts.errors
	end
	if counts.warnings > 0 then
		result = result .. (result == "" and "" or " ") .. "W:" .. counts.warnings
	end
	local clients = vim.lsp.get_clients({ bufnr = 0 }) -- Clients attached to current buffer
	local client_names = {}
	for _, client in ipairs(clients) do
		table.insert(client_names, client.name)
	end
	local client_str = #client_names > 0 and table.concat(client_names, ", ") or "No LSP"
	return result == "" and client_str or client_str .. " " .. result
end

local function set_statusline()
	vim.opt.statusline = table.concat({
		" ",
		get_lsp(),
		"%<",
		"%=",
		get_filename(),
		" ",
		"%l:%c  %P ",
	}, " ")
end

set_statusline()

vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach", "DiagnosticChanged", "ModeChanged", "BufEnter", "WinEnter" }, {
	group = augroup,
	callback = function()
		set_statusline()
	end,
})
