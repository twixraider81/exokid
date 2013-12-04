/**
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
module kernel.arch.x86.x64.state;

import kernel.common;

version(X86_64)
{
	/**
	 CPU state for x64
	 - http://www.lowlevel.eu/wiki/X64#Register
	 */
	struct CpuState
	{
		align (1):
		uintptr_t ds;
		uintptr_t r15, r14, r13, r12, r11, r10, r9, r8;
		uintptr_t rbp, rdi, rsi, rdx, rcx, rbx, rax;
		uintptr_t interrupt, error;
		uintptr_t rip, cs, eflags, rsp, ss;
	}
}