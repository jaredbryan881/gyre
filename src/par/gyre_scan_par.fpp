! Module   : gyre_scan_par
! Purpose  : frequency scan parameters
!
! Copyright 2013-2018 Rich Townsend
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'

module gyre_scan_par

  ! Uses

  use core_kinds

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: scan_par_t
     real(WP)        :: freq_min = 1._WP
     real(WP)        :: freq_max = 10._WP
     integer         :: n_freq = 10
     character(64)   :: freq_min_units = 'NONE'
     character(64)   :: freq_max_units = 'NONE'
     character(64)   :: freq_frame = 'INERTIAL'
     character(64)   :: grid_type = 'LINEAR'
     character(64)   :: grid_frame = 'INERTIAL'
     character(2048) :: tag_list = ''
  end type scan_par_t

  ! Access specifiers

  private

  public :: scan_par_t
  public :: read_scan_par

  ! Procedures

contains

  subroutine read_scan_par (unit, sc_p)

    integer, intent(in)                        :: unit
    type(scan_par_t), allocatable, intent(out) :: sc_p(:)

    integer                             :: n_sc_p
    integer                             :: i
    real(WP)                            :: freq_min
    real(WP)                            :: freq_max
    integer                             :: n_freq
    character(LEN(sc_p%freq_min_units)) :: freq_min_units
    character(LEN(sc_p%freq_max_units)) :: freq_max_units
    character(LEN(sc_p%freq_frame))     :: freq_frame
    character(LEN(sc_p%grid_type))      :: grid_type
    character(LEN(sc_p%grid_frame))     :: grid_frame
    character(LEN(sc_p%tag_list))       :: tag_list

    namelist /scan/ freq_min, freq_max, n_freq, freq_min_units, freq_max_units, &
         freq_frame, grid_type, grid_frame, tag_list

    ! Count the number of scan namelists

    rewind(unit)

    n_sc_p = 0

    count_loop : do
       read(unit, NML=scan, END=100)
       n_sc_p = n_sc_p + 1
    end do count_loop

100 continue

    ! Read scan parameters

    rewind(unit)

    allocate(sc_p(n_sc_p))

    read_loop : do i = 1, n_sc_p

       ! Set default values

       sc_p(i) = scan_par_t()

       freq_min = sc_p(i)%freq_min
       freq_max = sc_p(i)%freq_max
       n_freq = sc_p(i)%n_freq
       freq_min_units = sc_p(i)%freq_min_units
       freq_max_units = sc_p(i)%freq_max_units
       freq_frame = sc_p(i)%freq_frame
       grid_type = sc_p(i)%grid_type
       grid_frame = sc_p(i)%grid_frame
       tag_list = sc_p(i)%tag_list

       ! Read the namelist

       read(unit, NML=scan)

       ! Store read values

       sc_p(i)%freq_min = freq_min
       sc_p(i)%freq_max = freq_max
       sc_p(i)%n_freq = n_freq
       sc_p(i)%freq_min_units = freq_min_units
       sc_p(i)%freq_max_units = freq_max_units
       sc_p(i)%freq_frame = freq_frame
       sc_p(i)%grid_type = grid_type
       sc_p(i)%grid_frame = grid_frame
       sc_p(i)%tag_list = tag_list

    end do read_loop

    ! Finish

    return

  end subroutine read_scan_par

end module gyre_scan_par