#
# Deliberately uninstallable package for the test suite.
#
# tools/installcheckrelease must reject this every single time: nothing in
# Slowroll, Tumbleweed or Factory provides the capability below, and nothing
# ever will. If a run of the gate lets this through, the gate is broken.
#
Name:           slowroll-canary
Version:        0
Release:        0
Summary:        Uninstallable canary for the slowroll-tools test suite
License:        MIT
Group:          System/Base
BuildArch:      noarch
Requires:       this-capability-does-not-exist-anywhere

%description
Builds fine and cannot be installed. Used by test/assertions to prove that
the installcheck gate actually withholds a broken package from a release.

%prep

%build

%install
mkdir -p %{buildroot}%{_datadir}/%{name}
echo "canary" > %{buildroot}%{_datadir}/%{name}/README

%files
%{_datadir}/%{name}

%changelog
