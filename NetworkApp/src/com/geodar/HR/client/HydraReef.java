package com.geodar.HR.client;

import com.geodar.HR.client.view.StatusChart;
import com.geodar.HR.client.view.StatusGauge;
import com.google.gwt.core.client.EntryPoint;
import com.google.gwt.user.client.ui.HasHorizontalAlignment;
import com.google.gwt.user.client.ui.HorizontalPanel;
import com.google.gwt.user.client.ui.RootPanel;
import com.google.gwt.user.client.ui.VerticalPanel;

public class HydraReef implements EntryPoint {
	
	private HorizontalPanel hr;
	private VerticalPanel tmp1, tmp2,  tmp4, tmp5;
	private StatusGauge ph1, temp1,  temp3, temp4;
	private StatusChart ph1st, temp1st,  temp3st, temp4st;
	
	public void onModuleLoad() {
		
		hr = new HorizontalPanel();
		tmp1 = new VerticalPanel();
		tmp2 = new VerticalPanel();
		tmp4 = new VerticalPanel();
		tmp5 = new VerticalPanel();
		ph1 = new StatusGauge("Ph", "Main PH Probe", 7, 9);
		ph1st = new StatusChart("Ph");
		temp1 = new StatusGauge("Temp 1", "Display Tank", 18, 34,24,28,18,24,28,34);
		temp1st = new StatusChart("Temp 1");
		temp3 = new StatusGauge("Temp 3", "Electric Cabinet", 15, 55, 15, 40, 40, 50, 50, 55);
		temp3st = new StatusChart("Temp 3");
		temp4 = new StatusGauge("Temp 4", "Room Temperature", 10, 33, 18, 25, 10, 18, 25, 33);
		temp4st = new StatusChart("Temp 4");

		ph1.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);
		temp1.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);	
		temp3.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);
		temp4.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);
		
	
		tmp1.add(ph1);
		tmp1.add(ph1st);
		tmp2.add(temp1);
		tmp2.add(temp1st);
		tmp4.add(temp3);
		tmp4.add(temp3st);
		tmp5.add(temp4);
		tmp5.add(temp4st);
		
		hr.add(tmp1);
		hr.add(tmp2);
//		hr.add(tmp3);
		hr.add(tmp4);
		hr.add(tmp5);
		RootPanel.get().add(hr);

	}
}
