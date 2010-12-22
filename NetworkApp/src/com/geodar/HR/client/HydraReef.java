package com.geodar.HR.client;

import java.util.HashMap;
import java.util.Map;

import com.geodar.HR.client.view.Chart;
import com.geodar.HR.client.view.StatusChart;
import com.geodar.HR.client.view.StatusGauge;
import com.google.gwt.core.client.EntryPoint;
import com.google.gwt.user.client.History;
import com.google.gwt.user.client.HistoryListener;
import com.google.gwt.user.client.ui.ClickListener;
import com.google.gwt.user.client.ui.HasHorizontalAlignment;
import com.google.gwt.user.client.ui.HorizontalPanel;
import com.google.gwt.user.client.ui.Hyperlink;
import com.google.gwt.user.client.ui.RootPanel;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.user.client.ui.Widget;

public class HydraReef implements EntryPoint, HistoryListener {

	private HorizontalPanel hr;
	private VerticalPanel tmp1, tmp2, tmp4, tmp5, bottom;
	private StatusGauge ph1, temp1, temp3, temp4;
	private StatusChart ph1st, temp1st, temp3st, temp4st;
	public static final String INIT_STATE = "initstate";
	Map<String, Widget> cache = new HashMap<String, Widget>();
	private Chart testCh1, testCh2, testCh3, testCh4;

	public void onModuleLoad() {

		hr = new HorizontalPanel();
		tmp1 = new VerticalPanel();
		tmp2 = new VerticalPanel();
		tmp4 = new VerticalPanel();
		tmp5 = new VerticalPanel();
		bottom = new VerticalPanel();
		ph1 = new StatusGauge("Ph", "Main PH Probe", 7, 9);
		ph1st = new StatusChart("Ph");
		temp1 = new StatusGauge("Temp 1", "Display Tank", 18, 34, 24, 28, 18, 24, 28, 34);
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
		// hr.add(tmp3);
		hr.add(tmp4);
		hr.add(tmp5);

		final Hyperlink link1 = new Hyperlink("Show More", "testCh1");
		final Hyperlink link2 = new Hyperlink("Show More", "testCh2");
		final Hyperlink link3 = new Hyperlink("Show More", "testCh3");
		final Hyperlink link4 = new Hyperlink("Show More", "testCh4");

		tmp5.add(link2);
		tmp4.add(link1);
		tmp4.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);
		tmp5.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);
		tmp1.add(link3);
		tmp2.add(link4);
		testCh1 = new Chart("Temp 3");
		testCh2 = new Chart("Temp 4");
		testCh3 = new Chart("Ph");
		testCh4 = new Chart("Temp 1");
		link1.addClickListener(new ClickListener() {
			public void onClick(Widget sender) {
				bottom.clear();
				bottom.add(testCh1);
				cache.put(link1.getTargetHistoryToken(), testCh1);
			}
		});

		link2.addClickListener(new ClickListener() {
			public void onClick(Widget sender) {
				bottom.clear();
				bottom.add(testCh2);
				cache.put(link2.getTargetHistoryToken(), testCh2);
			}
		});
		link3.addClickListener(new ClickListener() {
			public void onClick(Widget sender) {
				bottom.clear();
				bottom.add(testCh3);
				cache.put(link3.getTargetHistoryToken(), testCh3);
			}
		});

		link4.addClickListener(new ClickListener() {
			public void onClick(Widget sender) {
				bottom.clear();
				bottom.add(testCh4);
				cache.put(link4.getTargetHistoryToken(), testCh4);
			}
		});

		RootPanel.get().add(hr);
		RootPanel.get().add(bottom);
		History.addHistoryListener(this);
		String token = History.getToken();
		if (token.length() == 0) {
			onHistoryChanged(INIT_STATE);
		} else {
			onHistoryChanged(token);
		}

	}

	@Override
	public void onHistoryChanged(String historyToken) {
		if (historyToken.equals(INIT_STATE)) {
		} else {

			Widget widget = cache.get(historyToken);
			bottom.clear();
			bottom.add(widget);
		}

	}
}
